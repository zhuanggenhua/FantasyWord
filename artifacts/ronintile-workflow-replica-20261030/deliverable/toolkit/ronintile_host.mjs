// 原网页Electron兼容层的两个缺口：GUID对象及真实tar.gz流。原111个业务模块不改。
export function installRoninTileHost(){
    const pending=[];
    const guid={raw:()=>crypto.randomUUID(),create:()=>({value:crypto.randomUUID()})};
    const archiver=type=>{
        if(type!=='tar')throw new Error('原导出流程请求了未定义的归档类型：'+type);
        const entries=[];
        return {
            append(data,options){
                entries.push({name:options.name,bytes:Array.from(typeof data==='string'?new TextEncoder().encode(data):data)});
            },
            finalize(){},
            pipe(compression){
                if(compression.format!=='gzip')throw new Error('原TARGZ导出缺少gzip阶段');
                return {pipe(destination){
                    const task=window.__ronintilePackArchive(entries).then(encoded=>{
                        const raw=atob(encoded),bytes=Uint8Array.from(raw,c=>c.charCodeAt(0));
                        destination.write(bytes);destination.end();
                    });
                    pending.push(task);return destination;
                }};
            }
        };
    };
    window.__RONINTILE_HOST__={guid,archiver,pending,pulverized:{compress:{gz:{stream:()=>({format:'gzip'})}}}};
}

export function bindRoninTileHost(source){
    const replacements=[
        ['guid:Oot()','guid:window.__RONINTILE_HOST__.guid'],
        ['archiver:Got()','archiver:window.__RONINTILE_HOST__.archiver'],
        ['pulverized:{compress:{gz:{stream(){return{pipe(){return this},on(){return this}}}}}}','pulverized:window.__RONINTILE_HOST__.pulverized']
    ];
    for(const [before,after] of replacements){
        if(source.split(before).length!==2)throw new Error('锁定版本的宿主绑定不符合预期：'+before);
        source=source.replace(before,after);
    }
    return source;
}
