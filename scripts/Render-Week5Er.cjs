const fs = require('fs');
const path = require('path');
// Usage: node scripts/Render-Week5Er.cjs [node_modules_directory] [browser_executable]
// Uses a fixed Mermaid release; only renders local ER sources.
const [moduleRoot, browserExecutable] = process.argv.slice(2);
const { chromium } = require(moduleRoot ? path.join(path.resolve(moduleRoot), 'playwright') : 'playwright');
process.chdir(path.resolve(__dirname, '..'));
(async () => {
  const browser = await chromium.launch(browserExecutable ? {executablePath:path.resolve(browserExecutable),headless:true} : {channel:'msedge',headless:true});
  try {
    const page = await browser.newPage({viewport:{width:1800,height:1200}, deviceScaleFactor:1});
    await page.setContent('<html><head><meta charset="utf-8"></head><body style="margin:0;background:white"><div id="diagram"></div></body></html>');
    await page.addScriptTag({url:'https://cdn.jsdelivr.net/npm/mermaid@11.12.0/dist/mermaid.min.js'});
    await page.evaluate(() => mermaid.initialize({startOnLoad:false,securityLevel:'strict',theme:'default',fontFamily:'Microsoft YaHei, sans-serif',er:{useMaxWidth:false,layoutDirection:'LR',minEntityWidth:120,entityPadding:15,fontSize:14}}));
    const dest=path.resolve('result/week5');
    fs.mkdirSync(dest,{recursive:true});
    for (const file of fs.readdirSync('docs/week5').filter(x=>x.endsWith('.mmd'))) {
      const source=fs.readFileSync(path.join('docs/week5',file),'utf8');
      const svg = await page.evaluate(async source=>{
        const result=await mermaid.render('erOutput',source);
        document.getElementById('diagram').innerHTML=result.svg;
        const element=document.querySelector('#diagram svg');
        const [x,y,w,h]=element.getAttribute('viewBox').split(/\s+/).map(Number);
        element.setAttribute('viewBox',`${x} ${y-90} ${w} ${h+90}`);
        element.setAttribute('height',h+90);
        const ns='http://www.w3.org/2000/svg';
        for (const [offset,label] of [
          [24,'v0.1 ER 模型　|　业务基数与参与约束'],
          [49,'端点：|| = 1..1　o| = 0..1　o{ = 0..N　|{ = 1..N　　PK 主码　FK 外码　UK 单属性候选码'],
          [74,'虚线：父键不参与子实体主码；最小 1 的业务要求不等于 DDL 已保证，条件性规则与组合候选码见规则清单。']
        ]) {
          const text=document.createElementNS(ns,'text');
          text.setAttribute('x',x+10); text.setAttribute('y',y-90+offset);
          text.setAttribute('style','font:16px Microsoft YaHei,sans-serif;fill:#202636');
          text.textContent=label; element.appendChild(text);
        }
        return element.outerHTML;
      },source);
      const name=path.basename(file,'.mmd');
      fs.writeFileSync(path.join(dest,name+'.svg'),svg);
      const el=page.locator('#diagram svg');
      const box=await el.boundingBox();
      await page.setViewportSize({width:Math.ceil(box.width)+10,height:Math.ceil(box.height)+10});
      await el.screenshot({path:path.join(dest,name+'.png'),timeout:60000});
      console.log(`RENDER_PASS ${name} ${Math.ceil(box.width)}x${Math.ceil(box.height)}`);
    }
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
