// 本模块只消费地图工程实际导出的世界数据。角色坐标只由同一个碰撞行走器推进。
const canvas=document.querySelector('#map'),ctx=canvas.getContext('2d');
const status=document.querySelector('#status');
const images=await Promise.all(IMAGE_URLS.map(url=>new Promise((resolve,reject)=>{
    const image=new Image();image.onload=()=>resolve(image);image.onerror=reject;image.src=url;
})));
const world=API.createMapRuntime(SCENE.bundle,SCENE.runtimeInputs);
if(world.portals.length)throw new Error('连续地图不应包含传送入口');
const spawn=SCENE.bundle.spawns[0];
const actor=API.createActor(world,spawn.x,spawn.y);
let activeBuilding=null,overview=false,zoom=4;const camera={x:0,y:0,scale:4};
let tickCount=0,automatic=true,lastTime=performance.now(),accumulator=0;
let maxStep=0,invalidSteps=0;const transitions=[],invalidPositions=[],keys=new Set();
const contains=(r,x,y)=>x>=r.x&&x<r.x+r.width&&y>=r.y&&y<r.y+r.height;
function updateInterior(){
    let next=null;
    for(const building of SCENE.buildings)if(contains(building.geometry.InteriorZone,actor.x,actor.y)){next=building;break;}
    if(next!==activeBuilding){
        if(activeBuilding)transitions.push({tick:tickCount,id:activeBuilding.id,entered:false,x:actor.x,y:actor.y});
        if(next)transitions.push({tick:tickCount,id:next.id,entered:true,x:actor.x,y:actor.y});
        activeBuilding=next;
        status.textContent=next?'室内 · '+next.name+' · 屋顶已揭开':'室外 · 屋顶正常显示';
    }
}
function tick(intent=null){
    const x=actor.x,y=actor.y;
    API.stepActor(world,actor,intent,32/60);tickCount++;
    const travelled=Math.hypot(actor.x-x,actor.y-y);maxStep=Math.max(maxStep,travelled);
    if(travelled>32/60+1e-7)throw new Error('角色单步移动超出预算');
    if(!API.isValid(world,actor.x,actor.y)){
        invalidSteps++;
        if(invalidPositions.length<10)invalidPositions.push({tick:tickCount,from:[x,y],to:[actor.x,actor.y]});
    }
    updateInterior();
}
function setPath(x,y){
    if(!API.isValid(world,x,y))return false;
    const path=API.findPath(world,actor.x,actor.y,x,y);
    if(!path)return false;
    // 规划线段与实际逐帧步长的采样相位不同。保留逐步碰撞检查，不使用 clear 快速跳过路径。
    actor.path=path.map(point=>({x:point.x,y:point.y}));return true;
}
function snapshot(){return {mapId:SCENE.mapId,x:actor.x,y:actor.y,active:activeBuilding?[activeBuilding.id]:[],
    roofVisible:Object.fromEntries(SCENE.buildings.map(b=>[b.id,activeBuilding!==b])),
    travelled:actor.travelled,tickCount,maxStep,invalidSteps,camera:{...camera},transitions:[...transitions],
    invalidPositions,portals:world.portals.length,sourceSha256:SCENE.sourceSha256};}
// 静态物件只排序一次。每帧仅插入角色，不重新分配整张地图的绘制队列。
const drawables=SCENE.objects.map(o=>({sortY:o.sortY,image:o.image,x:o.x,y:o.y,coverOwner:null}));
for(const building of SCENE.buildings)drawables.push({sortY:building.y+building.height,
    image:building.cover,x:building.x,y:building.y,coverOwner:building});
drawables.sort((a,b)=>a.sortY-b.sortY);
function drawActor(){ctx.drawImage(images[SCENE.actor],Math.round(actor.x-SCENE.actorAnchor[0]),Math.round(actor.y-SCENE.actorAnchor[1]));}
function render(){
    const scale=overview?Math.min(canvas.width/SCENE.width,canvas.height/SCENE.height):zoom;
    const vw=canvas.width/scale,vh=canvas.height/scale;
    camera.scale=scale;
    camera.x=overview?0:Math.max(0,Math.min(SCENE.width-vw,actor.x-vw/2));
    camera.y=overview?0:Math.max(0,Math.min(SCENE.height-vh,actor.y-vh/2));
    ctx.setTransform(1,0,0,1,0,0);ctx.clearRect(0,0,canvas.width,canvas.height);
    ctx.imageSmoothingEnabled=false;ctx.setTransform(scale,0,0,scale,-Math.round(camera.x)*scale,-Math.round(camera.y)*scale);
    ctx.drawImage(images[SCENE.background],0,0);
    let actorDrawn=false;
    for(const entry of drawables){
        if(!actorDrawn&&entry.sortY>actor.y){drawActor();actorDrawn=true;}
        if(entry.coverOwner!==null&&entry.coverOwner===activeBuilding)continue;
        ctx.drawImage(images[entry.image],entry.x,entry.y);
    }
    if(!actorDrawn)drawActor();
    ctx.setTransform(1,0,0,1,0,0);
}
const intent={x:0,y:0};
function directions(){
    intent.x=(keys.has('d')||keys.has('arrowright')?1:0)-(keys.has('a')||keys.has('arrowleft')?1:0);
    intent.y=(keys.has('s')||keys.has('arrowdown')?1:0)-(keys.has('w')||keys.has('arrowup')?1:0);
    return intent;
}
function frame(now){
    if(automatic){accumulator+=Math.min(.1,(now-lastTime)/1000);while(accumulator>=1/60){tick(directions());accumulator-=1/60;}}
    lastTime=now;render();requestAnimationFrame(frame);
}
function reset(){API.arrive(world,actor,spawn.x,spawn.y);updateInterior();render();}
window.addEventListener('keydown',event=>{
    const key=event.key.toLowerCase();if(['w','a','s','d','arrowup','arrowdown','arrowleft','arrowright'].includes(key)){
        event.preventDefault();keys.add(key);
    }else if(key==='m'){overview=!overview;render();}else if(key==='r')reset();
});
window.addEventListener('keyup',event=>keys.delete(event.key.toLowerCase()));
window.addEventListener('blur',()=>keys.clear());
canvas.addEventListener('pointerdown',event=>{
    const box=canvas.getBoundingClientRect();
    const x=(event.clientX-box.left)*canvas.width/box.width/camera.scale+Math.round(camera.x);
    const y=(event.clientY-box.top)*canvas.height/box.height/camera.scale+Math.round(camera.y);
    setPath(x,y);
});
canvas.addEventListener('wheel',event=>{event.preventDefault();overview=false;zoom=Math.max(2,Math.min(8,zoom+(event.deltaY<0?1:-1)));render();},{passive:false});
document.querySelector('#overview').onclick=()=>{overview=!overview;render();};
document.querySelector('#reset').onclick=reset;
// 验收入口只发出移动指令并推进同一个步进函数，不提供任意设置角色坐标的接口。
window.__town=Object.freeze({ready:true,buildings:SCENE.buildings,snapshot,
    pause:()=>{automatic=false;keys.clear();},resume:()=>{automatic=true;accumulator=0;lastTime=performance.now();},
    overview:value=>{overview=value;render();},
    blocked:(x,y)=>!API.isValid(world,x,y),
    runTo:(x,y)=>{
        if(!setPath(x,y))throw new Error('目标不可达：'+x+','+y);
        let ticks=0;while(actor.path&&ticks<12000){tick();ticks++;}
        if(Math.hypot(actor.x-x,actor.y-y)>.1)throw new Error('未走到目标');
        render();return snapshot();
    },
    advanceIntent:(x,y,count)=>{for(let i=0;i<count;i++)tick({x,y});render();return snapshot();}
});
status.textContent='室外 · 屋顶正常显示';updateInterior();render();requestAnimationFrame(frame);
