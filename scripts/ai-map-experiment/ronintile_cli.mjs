// 在隔离的本地 Chromium 内驱动原版 RoninTile 导出 API；用户素材不离开本机。
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {installRoninTileHost,bindRoninTileHost} from './ronintile_host.mjs';
const require=createRequire(import.meta.url);
const {chromium}=require('playwright-core');
const here=path.dirname(fileURLToPath(import.meta.url));
const flags=Object.fromEntries(process.argv.slice(2).reduce((pairs,value,index,all)=>{
    if(index%2===0)pairs.push([value.replace(/^--/,''),all[index+1]]);return pairs;
},[]));
if(!flags.recipe||!flags.output)throw new Error('用法：node ronintile_cli.mjs --recipe 工作流.json --output 新目录 [--engine 原引擎目录]');
const workspace=path.resolve(here,'../..');
const lock=JSON.parse(fs.readFileSync(path.join(here,'ronintile-engine-lock.json'),'utf8'));
const engineRoot=path.resolve(flags.engine??path.join(lock.localReferenceBase==='toolkit'?here:workspace,lock.localReference));
const engineFile=path.join(engineRoot,'index.js');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const engineBytes=fs.readFileSync(engineFile);
if(hash(engineBytes)!==lock.sha256)throw new Error('原引擎版本与锁文件不一致，拒绝执行未知版本');
const hostedEngine=bindRoninTileHost(engineBytes.toString('utf8'));
const recipePath=path.resolve(flags.recipe);
const recipeFolder=path.dirname(recipePath);
const recipe=JSON.parse(fs.readFileSync(recipePath,'utf8'));
const output=path.resolve(flags.output);
if(fs.existsSync(output))throw new Error('输出目录已存在，拒绝覆盖：'+output);
fs.mkdirSync(output,{recursive:true});
const sourceAudit=[];
const loadImage=file=>{
    const target=path.resolve(recipeFolder,file),bytes=fs.readFileSync(target);
    sourceAudit.push({path:target,sha256:hash(bytes),bytes:bytes.length});
    return 'data:image/png;base64,'+bytes.toString('base64');
};
const input=structuredClone(recipe);
for(const step of input.steps??[])if(step.op==='import')step.imageData=loadImage(step.image);
if(input.project){
    const project=path.resolve(recipeFolder,input.project),bytes=fs.readFileSync(project);
    sourceAudit.push({path:project,sha256:hash(bytes),bytes:bytes.length});input.projectData=bytes.toString('utf8');
}
const missingResources=[],blockedRequests=[],errors=[];
const server=http.createServer((request,response)=>{
    const url=new URL(request.url,'http://127.0.0.1');
    if(url.pathname==='/ronintile/'||url.pathname==='/'){
        response.setHeader('Content-Type','text/html;charset=utf-8');
        response.end('<!doctype html><html><head><link rel="stylesheet" href="/ronintile/assets/index-DUUNff8v.css"></head><body><div id="root"></div><script type="module" src="/engine.js"></script></body></html>');return;
    }
    if(url.pathname==='/engine.js'){
        response.setHeader('Content-Type','application/javascript');response.end(hostedEngine);return;
    }
    const file=path.resolve(engineRoot,'public','.'+decodeURIComponent(url.pathname));
    if(file!==engineFile&&!file.startsWith(path.join(engineRoot,'public')+path.sep)){response.writeHead(403);response.end();return;}
    if(!fs.existsSync(file)||!fs.statSync(file).isFile()){
        missingResources.push(url.pathname);response.writeHead(404);response.end();return;
    }
    const type={'.js':'application/javascript','.css':'text/css','.png':'image/png','.svg':'image/svg+xml','.otf':'font/otf'}[path.extname(file)]??'application/octet-stream';
    response.setHeader('Content-Type',type);response.end(fs.readFileSync(file));
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
let browser;
try{
    browser=await chromium.launch({headless:true,args:['--enable-unsafe-swiftshader']});
    const page=await browser.newPage({viewport:{width:1280,height:800}});
    await page.exposeFunction('__ronintilePackArchive',entries=>execFileSync('python',[path.join(here,'pack_ronintile_unity.py')],
        {input:JSON.stringify(entries),encoding:'utf8',maxBuffer:64*1024*1024,windowsHide:true}));
    await page.addInitScript(installRoninTileHost);
    page.on('pageerror',error=>errors.push(String(error)));
    page.on('console',message=>{
        const text=message.text();
        if(text.startsWith('RONINTILE_STEP ')){
            fs.appendFileSync(path.join(output,'steps.jsonl'),text.slice(15)+'\n');
            if(flags.quiet!=='true')console.log(text);
        }
    });
    await page.route('**/*',route=>{
        const url=new URL(route.request().url());
        if(url.hostname==='127.0.0.1'||['data:','blob:'].includes(url.protocol))return route.continue();
        blockedRequests.push(url.origin);return route.abort();
    });
    await page.goto(`http://127.0.0.1:${server.address().port}/ronintile/?lang=zh`);
    await page.waitForFunction(()=>window.tileroninX&&window.__TILERONINX_BROWSER_RUNTIME__,{timeout:20000});
    const result=await page.evaluate(async recipe=>{
        const runtime=window.__TILERONINX_BROWSER_RUNTIME__;
        const core=window.tileroninX;
        const req=runtime.require;
        const vfs=runtime.virtualFs;
        const trace=[];
        const getTile=point=>{
            if(point===null||point===false)return false;
            if(typeof point==='string'){
                if(!references.has(point))throw new Error('未知图块引用：'+point);return references.get(point);
            }
            const tile=core.getTileSet(point[0],point[1]);
            if(!tile)throw new Error('素材集坐标没有图块：'+JSON.stringify(point));return tile;
        };
        const points=step=>{
            if(step.cells)return step.cells.map(p=>({x:p[0],y:p[1]}));
            if(step.rect){const [x,y,w,h]=step.rect,result=[];for(let j=0;j<h;j++)for(let i=0;i<w;i++)result.push({x:x+i,y:y+j});return result;}
            throw new Error('必须提供cells或rect');
        };
        const waitTiles=async()=>{
            const tiles=new Set(),dependencies=[];
            for(const layer of core.getLayersSandbox())for(const item of Object.values(layer.grid.getTiles()))if(item){
                tiles.add(item.tile);item.tile.getRelationsDependencies(dependencies);
            }
            for(const dependency of dependencies){tiles.add(dependency.tile);if(dependency.other)tiles.add(dependency.other);}
            const widths=[];
            for(const tile of tiles)for(const {r} of tile.getRelations())if(r?.getBorderSet){
                for(const source of r.getBorderSet().borderSources??[])if(source.widthPromise)widths.push(source.widthPromise);
            }
            await Promise.all(widths);
            // 原版边界测宽完成后才异步重建imageCache；等待缓存引用连续三帧稳定。
            const deadline=Date.now()+30000;let previous=[],stable=0;
            while(stable<3){
                if(Date.now()>deadline)throw new Error('原版图块图像缓存30秒内未稳定');
                const current=[...tiles].map(tile=>tile.getImage());await Promise.all(current);
                await new Promise(resolve=>requestAnimationFrame(resolve));
                stable=current.length===previous.length&&current.every((value,i)=>value===previous[i])?stable+1:0;
                previous=current;
            }
        };
        const placementCount=()=>core.getLayersSandbox().reduce((n,l)=>n+Object.keys(l.grid.getTiles()).length,0);
        const marshal=value=>{
            if(Array.isArray(value))return value.map(marshal);
            if(value&&typeof value==='object'){
                if('$tile' in value)return getTile(value.$tile);
                if('$source' in value)return getTile(value.$source).getSource();
                if('$ref' in value){if(!references.has(value.$ref))throw new Error('未知引用：'+value.$ref);return references.get(value.$ref);}
                if('$new' in value){const Constructor=req('./js/'+value.$new+'.js');return new Constructor(...(value.args??[]).map(marshal));}
                return Object.fromEntries(Object.entries(value).map(([key,v])=>[key,marshal(v)]));
            }return value;
        };
        const references=new Map();
        const projectMetadata=recipe.metadata??(recipe.projectData?JSON.parse(recipe.projectData).extra?.workflow:undefined);
        if(projectMetadata)core.onSaveSubscribe(extra=>{extra.workflow=projectMetadata;});
        const save=async name=>{
            let timer;
            try{return await Promise.race([
                new Promise(resolve=>core.saveData('/work/'+name+'.json',()=>resolve(vfs.readFileSync('/work/'+name+'.json')))),
                new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('原版工程保存超过30秒，未取得真实保存回调')),30000);})
            ]);}finally{clearTimeout(timer);}
        };
        if(recipe.projectData){vfs.setText('/work/input.json',recipe.projectData);if(!core.loadData('/work/input.json'))throw new Error('原引擎拒绝加载工程');}
        else{core.newData({shape:recipe.shape??0});const errors=[];core.setTileSize(recipe.tileSize??8,[],errors);if(errors.length)throw new Error(JSON.stringify(errors));}
        for(const [index,step] of (recipe.steps??[]).entries()){
            console.info('RONINTILE_STEP '+JSON.stringify({index,op:step.op,status:'started'}));
            const undo=[],errors=[];let details={};
            if(step.op==='import'){
                // 与原版文件选择器一致，先完整解码PNG为NativeImage，再交给imageToSources切分。
                const NativeImage=runtime.electron.nativeImage.createFromDataURL(step.imageData).constructor;
                const image=await NativeImage.fromDataUrlWithCanvas(step.imageData);
                const sources=core.imageToSources(image),TileBase=req('./js/TileBase.js');
                const at=step.at??[0,0];
                core.setTilesSet(sources.map(s=>({x:s.pos.x+at[0],y:s.pos.y+at[1],tile:new TileBase(s.src)})),undo);
                details={imageSize:image.getSize(),tilesImported:sources.length,at};
            }else if(step.op==='layer'){
                if(step.index===undefined)core.addLayerSandbox(undo);
                const z=step.index??core.getLayersSandbox().length-1;
                core.editLayerSandbox(z,step.visible??true,step.name??null,undo);details={layerIndex:z};
            }else if(step.op==='prop'){
                const tiles=points(step).map(p=>({tile:core.getTileSet(p.x,p.y)??false,pos:p}));
                core.groupTilesAsProp(tiles,undo,errors);details={components:tiles.filter(t=>t.tile).length};
                if(step.background)for(const t of tiles)if(t.tile)core.setPropBackground(t.tile,getTile(step.background),undo);
            }else if(step.op==='relation'){
                const origin=getTile(step.tile),other=step.other===null?false:getTile(step.other);
                const type=step.kind==='blob'?'Blob':step.kind==='wang'?'Wang':null;
                if(!type)throw new Error('关系类型必须为blob或wang');
                if(step.slots?.length!==12)throw new Error('原版边界定义必须包含12个槽位');
                const relation=origin.getRelation(other);
                const Relation=req('./js/TileRelation'+type+'.js');
                if(!(relation instanceof Relation))throw new Error('必须先Build Borders创建该关系，再配置原关系的12个槽位');
                const border=relation.getBorderSet();
                for(const [i,slot] of step.slots.entries()){
                    border.setSource(i,getTile(slot.tile).getSource(),undo);
                    border.setRotation(i,slot.r??0,undo);
                    border.setFlipX(i,slot.fx??false,undo);
                    border.setFlipY(i,slot.fy??false,undo);
                    if(i<4)border.setCutoff(i,slot.cutoff??0,undo);
                    else border.setComposite(i,slot.c??true,undo);
                }
                if(type==='Blob'){
                    const started=performance.now();
                    while(!border.isReady){if(performance.now()-started>10000)throw new Error('原版Blob槽位解码超时');await new Promise(r=>setTimeout(r,5));}
                }
                details={kind:step.kind,slots:12};
            }else if(step.op==='build-borders'){
                const selected=points(step),original=selected.map(p=>({pos:p,tile:core.getTileSet(p.x,p.y)})).filter(v=>v.tile),tiles=original.map(v=>v.tile);
                const origin=selected[0];
                const generated=(step.kind==='blob'?core.buildBordersBlob:core.buildBordersWang)(tiles,undo,errors);
                const add=[];
                for(const item of generated){
                    const previous=tiles.indexOf(item.tile);
                    if(previous>=0){const p=original.find(p=>p.tile===item.tile).pos;core.moveTilesSet([p],item.pos.x+origin.x-p.x,item.pos.y+origin.y-p.y,undo);}
                    else add.push({x:item.pos.x+origin.x,y:item.pos.y+origin.y,tile:item.tile});
                }
                core.setTilesSet(add,undo);details={generatedTiles:add.length,totalTiles:generated.length};
            }else if(step.op==='bind-borders'){
                const base=getTile(step.tile),Relation=req('./js/TileRelationBlobBorder.js'),TileBase=req('./js/TileBase.js');
                const offsets=[[-1,-1],[0,-1],[1,-1],[1,0],[1,1],[0,1],[-1,1],[-1,0]];
                const roles=base.getRelations().filter(r=>r.r instanceof Relation&&!r.r.isBorder);
                let bound=0;
                for(const role of roles){
                    const matrix=role.r.getIndexMatrix();
                    const rule=step.rules.find(rule=>rule.neighbors.every(n=>{
                        const index=offsets.findIndex(p=>p[0]===n.x&&p[1]===n.y);
                        if(index<0)throw new Error('规则邻居不在8邻接网格内');
                        return n.value===0||(n.value===1?matrix[index]===base:matrix[index]!==base);
                    }));
                    if(!rule)continue;
                    const replacement=new TileBase(getTile(rule.source).getSource());
                    const oldPosition=core.getTilePositionSet(role.t);
                    core.replaceBlobBorder(base,matrix,replacement,undo,errors);
                    if(oldPosition)core.setTilesSet([{x:oldPosition.x,y:oldPosition.y,tile:replacement}],undo);
                    bound++;
                }
                details={boundRoles:bound,availableRoles:roles.length,source:'原素材预绘边界，使用原版replaceBlobBorder绑定'};
            }else if(step.op==='paint'||step.op==='draw'){
                const tile=step.tile===null?null:getTile(step.tile);
                const cells=points(step).map(p=>({...p,tile}));
                (step.op==='paint'?core.paintTilesSandbox:core.drawTilesSandbox)(cells,undo,step.layer??0);details={cells:cells.length};
            }else if(step.op==='stamp'){
                const cells=points(step),at=step.at??[0,0],origin=step.origin??[Math.min(...cells.map(p=>p.x)),Math.min(...cells.map(p=>p.y))];
                const items=cells.map(p=>({x:p.x-origin[0]+at[0],y:p.y-origin[1]+at[1],tile:core.getTileSet(p.x,p.y)??null}));
                (step.smart===false?core.drawTilesSandbox:core.paintTilesSandbox)(items,undo,step.layer??0);details={cells:items.length};
            }else if(step.op==='undo'){const before=placementCount();core.performUndo();details={placementsBefore:before,placementsAfter:placementCount()};}
            else if(step.op==='redo'){const before=placementCount();core.performRedo();details={placementsBefore:before,placementsAfter:placementCount()};}
            else if(step.op==='save'){details={file:step.name+'.json'};await save(step.name);}
            else if(step.op==='reload'){
                const file='/work/'+step.name+'.json';if(!core.loadData(file))throw new Error('原引擎工程重读失败：'+file);
            }else if(step.op==='call'){
                // 只调用原引擎已经导出的函数，复杂参数显式绑定原类/图块，不能注入脚本。
                if(typeof core[step.function]!=='function')throw new Error('原引擎没有函数：'+step.function);
                const value=await core[step.function](...(step.args??[]).map(marshal));
                if(step.as)references.set(step.as,value);
                details={function:step.function};
            }else if(step.op==='export'){
                await waitTiles();
                const domain=step.domain??'map';
                const formatName=step.format??'JSON';
                const suffix=core.getTileShape()===0?'tsfo':'tsfi';
                const format=req('./js/tileroninXExport.js').parseExportFormat(`/browser/ronintile/format/${domain}/${formatName}.${suffix}`);
                const selection=points(step);
                await (domain==='set'?core.exportPackageSet:core.exportPackageMap)(selection,'/work/exports/'+step.name,format.format);
                await Promise.all(window.__RONINTILE_HOST__.pending);
                details={domain,format:formatName};
            }else if(step.op==='render'){
                await waitTiles();const image=await core.toImageSandbox(points(step),step.layer??-1);
                vfs.writeFileSync('/work/'+step.name+'.png',image.toPNG());details={size:image.getSize()};
            }else throw new Error('未知步骤：'+step.op);
            if(errors.length)throw new Error(JSON.stringify({step:index,op:step.op,errors:errors.map(e=>e.msg)}));
            if(undo.length)core.saveUndoState(undo);
            trace.push({index,op:step.op,...details});
            console.info('RONINTILE_STEP '+JSON.stringify({index,op:step.op,status:'pass',...details}));
        }
        await waitTiles();const project=JSON.parse(await save('project'));
        const files=[];
        for(const [filename,value] of vfs.files)if(filename.startsWith('/work/')&&filename!=='/work/input.json'){
            if(value.text!==undefined)files.push({name:filename.slice(6),text:value.text});
            else if(value.bytes)files.push({name:filename.slice(6),bytes:Array.from(value.bytes)});
        }
        return {version:core.getVersionID(),trace,files,summary:{sources:project.sources.length,tiles:project.tiles.length,relations:project.relations.length,placements:project.sandbox.length,layers:project.sandbox_layers}};
    },input);
    for(const file of result.files){
        const destination=path.resolve(output,file.name);
        if(!destination.startsWith(output+path.sep))throw new Error('导出文件超出任务目录：'+file.name);
        fs.mkdirSync(path.dirname(destination),{recursive:true});
        fs.writeFileSync(destination,file.text!==undefined?file.text:Buffer.from(file.bytes));
    }
    const report={status:errors.length?'fail':'pass',engine:lock,recipeSha256:hash(fs.readFileSync(recipePath)),sourceAudit,
        hostedEngineSha256:hash(Buffer.from(hostedEngine)),
        hostAdaptations:[{id:'guid-create',reason:'原网页宿主只实现raw，但ExportGUIDBlock调用create().value',implementation:'真实UUID及value对象'},
            {id:'tar-gzip-stream',reason:'原网页归档宿主只拼接文本，未生成tar.gz',implementation:'保留原导出器文件列表，使用Python tarfile生成真实归档并等待写入完成'}],
        version:result.version,trace:result.trace,summary:result.summary,errors,blockedRequests,missingResources:[...new Set(missingResources)],unityVerified:false};
    fs.writeFileSync(path.join(output,'workflow-report.json'),JSON.stringify(report,null,2));
    await page.screenshot({path:path.join(output,'reference-editor.png')});
    if(errors.length)throw new Error('原引擎页面错误：'+errors.join(';'));
    console.log(JSON.stringify({status:'pass',output,summary:{...result.summary,layers:result.summary.layers.length},steps:result.trace.length,blockedRequests:blockedRequests.length}));
}catch(error){fs.writeFileSync(path.join(output,'failure.json'),JSON.stringify({status:'fail',error:String(error),stack:error.stack,errors,blockedRequests},null,2));throw error;}
finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
