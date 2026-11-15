// 实际 Chromium 验收：逐栋沿同一世界中的门洞行走，不调用重置或传送。
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const playwright=require('playwright-core');
const output=path.resolve(process.argv[2]);
const browser=await playwright.chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1100,height:860},deviceScaleFactor:1});
const errors=[],requests=[],navigations=[];let loaded=false;
page.on('pageerror',error=>errors.push(String(error)));
page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
page.on('framenavigated',frame=>{if(loaded&&frame===page.mainFrame())navigations.push(frame.url());});
let result;
try{
    await page.goto(pathToFileURL(path.join(output,'preview.html')).href);
    await page.waitForFunction(()=>window.__town?.ready,{timeout:30000});
    loaded=true;
    const keyBefore=await page.evaluate(()=>window.__town.snapshot());
    await page.keyboard.down('d');await page.waitForTimeout(250);await page.keyboard.up('d');
    const keyAfter=await page.evaluate(()=>window.__town.snapshot());
    const keyDistance=keyAfter.x-keyBefore.x;
    if(keyDistance<=0||keyDistance>14)throw new Error('真实键盘移动失败');
    const clickTarget={x:keyAfter.x+12,y:keyAfter.y};
    const box=await page.locator('#map').boundingBox();const camera=keyAfter.camera;
    await page.mouse.click(box.x+(clickTarget.x-Math.round(camera.x))*camera.scale*box.width/960,
        box.y+(clickTarget.y-Math.round(camera.y))*camera.scale*box.height/640);
    await page.waitForTimeout(650);
    await page.evaluate(()=>window.__town.pause());
    const clickAfter=await page.evaluate(()=>window.__town.snapshot());
    if(Math.hypot(clickAfter.x-clickTarget.x,clickAfter.y-clickTarget.y)>.2)throw new Error('真实点击寻路失败');
    const initial=await page.evaluate(()=>window.__town.snapshot());
    const buildings=await page.evaluate(()=>window.__town.buildings);
    const checks=[];
    for(const building of buildings){
        const outside=building.geometry.ExteriorPoint,inside=building.geometry.InteriorPoint;
        const before=await page.evaluate(p=>window.__town.runTo(p.x,p.y),outside);
        if(before.active.includes(building.id))throw new Error('门外已误判为室内：'+building.id);
        if(building.id==='inn')await page.screenshot({path:path.join(output,'inn-outside.png')});
        const entered=await page.evaluate(p=>window.__town.runTo(p.x,p.y),inside);
        if(entered.active.length!==1||entered.active[0]!==building.id||entered.roofVisible[building.id])throw new Error('进入后屋顶未正确揭开：'+building.id);
        if(buildings.some(b=>b.id!==building.id&&!entered.roofVisible[b.id]))throw new Error('错误隐藏其他建筑屋顶');
        await page.screenshot({path:path.join(output,building.id+'-inside.png')});
        let wallCheck='open-canopy';
        if(building.geometry.WallProbe){
            const wall=building.geometry.WallProbe;
            if(!await page.evaluate(p=>window.__town.blocked(p.x,p.y),wall))throw new Error('后墙未阻挡');
            const stopped=await page.evaluate(()=>window.__town.advanceIntent(0,-1,100));
            if(stopped.y<=wall.y||stopped.invalidSteps)throw new Error('墙体检查失败 '+building.id+
                '：角色y='+stopped.y+'，墙y='+wall.y+'，无效位置='+JSON.stringify(stopped.invalidPositions));
            wallCheck='pass';
        }
        for(const probe of building.furnitureProbes){
            if(!await page.evaluate(p=>window.__town.blocked(p.x,p.y),probe))throw new Error('家具未参与碰撞：'+building.id);
        }
        const exited=await page.evaluate(p=>window.__town.runTo(p.x,p.y),outside);
        if(exited.active.includes(building.id)||!exited.roofVisible[building.id])throw new Error('离开后屋顶未恢复：'+building.id);
        if(building.id==='inn')await page.screenshot({path:path.join(output,'inn-exited.png')});
        checks.push({id:building.id,name:building.name,entered:true,exited:true,roof_hide_restore:'pass',
            walls:wallCheck,furniture_probes:building.furnitureProbes.length,
            entry_tick:entered.tickCount,exit_tick:exited.tickCount});
    }
    const final=await page.evaluate(()=>window.__town.snapshot());
    if(final.mapId!==initial.mapId||final.sourceSha256!==initial.sourceSha256||final.portals!==0||final.invalidSteps||final.maxStep>32/60+1e-7||errors.length||requests.length||navigations.length)
        throw new Error('连续世界或运行校验失败');
    await page.evaluate(()=>window.__town.overview(true));
    await page.screenshot({path:path.join(output,'preview-overview.png')});
    result={status:'pass',checks,initial,final,input:{keyboardDistance:keyDistance,clickReached:true},
        errors,externalRequests:requests,pageNavigations:navigations,
        note:'所有移动均通过同一实际步进函数推进；未重置角色位置，未切换地图。'};
}catch(error){result={status:'fail',error:String(error),stack:error.stack,errors,externalRequests:requests};}
finally{await browser.close();}
fs.writeFileSync(path.join(output,'preview-qa.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify({status:result.status,buildings:result.checks?.length,error:result.error}));
if(result.status!=='pass')process.exitCode=1;
