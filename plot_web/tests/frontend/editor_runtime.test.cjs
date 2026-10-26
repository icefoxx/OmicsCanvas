const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {File} = require('node:buffer');
const source = fs.readFileSync(path.join(__dirname, '../../static/editor.js'), 'utf8');

function element() {
  const classes = new Set();
  return {textContent: '', value: '', hidden: false, innerHTML: '', children: [], dataset: {},
    style: {}, attrs: {}, validity: {valid: true},
    classList: {add: x => classes.add(x), remove: x => classes.delete(x),
      contains: x => classes.has(x), toggle(x, on) {if (on) classes.add(x); else classes.delete(x);}},
    append(...items) {this.children.push(...items);}, appendChild(item) {this.children.push(item);},
    setAttribute(k,v) {this.attrs[k]=v;}, removeAttribute(k) {delete this.attrs[k];},
    setCustomValidity() {}, querySelectorAll() {return [];},
  };
}
function runtime({downloads = false} = {}) {
  const els = new Map();
  const context = {URLSearchParams, FormData, File, Blob, Date, console, setTimeout, clearTimeout,
    window: {location: {search: '?plugin=group_heatmap'}},
    document: {addEventListener() {}, querySelectorAll() {return [];},
      getElementById(id) {if (!els.has(id)) els.set(id,element());return els.get(id);},
      createElement: element},
  };
  vm.createContext(context);
  vm.runInContext(source, context);
  context.stateRef = vm.runInContext('state',context);
  vm.runInContext(`renderValidation = () => {}; updateInstantPreview = async () => {};
    renderParamContentArea = () => {}; renderStageDataDrawer = () => {};
    syncJsonFromParams = () => {};`,context);
  if (!downloads) vm.runInContext('renderDownloads = () => {};',context);
  return {context, state: context.stateRef, els};
}
function deferred() {let resolve;const promise = new Promise(r=>resolve=r);return {promise,resolve};}

test('edits during a render are coalesced into the latest request; stale outputs are not published', async()=>{
  const {context:c,state:s,els} = runtime();
  const first=deferred(), calls=[], published=[];
  c.fetch=async(url,options)=>{calls.push(JSON.parse(options.body));const result=calls.length===1?await first.promise:{status:'completed',outputs:{preview:'B.png'}};return {ok:true,json:async()=>result};};
  c.renderDownloads=out=>{if(out.preview)published.push(out.preview);};
  s.params={title:'A'};
  const running=c.runDemoSilent();
  s.params.title='B';c.markFigureDirty();await c.runDemoSilent();
  s.params.title='C';c.markFigureDirty();await c.runDemoSilent();
  first.resolve({status:'completed',outputs:{preview:'A.png'}});
  await running;
  assert.deepEqual(calls.map(x=>x.params.title),['A','C']);
  assert.equal(published.includes('A.png'),false);
  assert.equal(s.renderedRevision,s.revision);
  assert.equal(els.get('editorStateText').textContent,'Synced');
});

test('user file bytes and secondary inputs go to /run, never /run-demo',async()=>{
  const {context:c,state:s}=runtime();
  s.detail={inputs:[{id:'input',required:true},{id:'annot',required:true}]};
  s.customFiles={input:new File(['x,y\n1,2\n'],'my-data.csv'),annot:new File(['id,group\n1,A\n'],'groups.csv')};
  s.params={title:'My experiment'};
  let request;
  c.fetch=async(url,options)=>{request={url,...options};return {ok:true,json:async()=>({})};};
  await c.requestFigure();
  assert.equal(request.url,'/api/plugins/group_heatmap/run');
  assert.equal(await request.body.get('input').text(),'x,y\n1,2\n');
  assert.equal(await request.body.get('annot').text(),'id,group\n1,A\n');
  assert.equal(JSON.parse(request.body.get('params')).title,'My experiment');
});

test('required user inputs cannot silently fall back to example files',async()=>{
  const {context:c,state:s}=runtime();
  s.detail={inputs:[{id:'input',required:true},{id:'annot',required:true}]};
  s.customFiles={input:new File(['x\n1'],'mine.csv')};
  c.fetch=()=>assert.fail('must not send incomplete data');
  await assert.rejects(c.requestFigure(),/annot/);
});

test('failed file parsing preserves the previous selected data and reports failure',async()=>{
  const {context:c,state:s,els}=runtime();
  const previous=new File(['x\n1'],'old.csv');
  s.customFiles={input:previous};
  s.inputPreview={files:{input:{filename:'old.csv',columns:['x']}}};
  c.fetch=async()=>({ok:true,json:async()=>({files:{input:{filename:'bad.xlsx',error:'Unreadable workbook'}}})});
  await c.loadUserFile('input',new File(['bad'],'bad.xlsx'));
  assert.equal(s.customFiles.input,previous);
  assert.equal(s.inputPreview.files.input.filename,'old.csv');
  assert.match(els.get('jobStatus').textContent,/not loaded/);
  assert.equal(s.isUploading,false);
});

test('an upload invalidates an in-flight example result',async()=>{
  const {context:c,state:s}=runtime();
  const first=deferred(),published=[];
  c.fetch=async()=>({ok:true,json:async()=>await first.promise});
  c.renderDownloads=out=>{if(out.preview)published.push(out.preview);};
  const rendering=c.runDemoSilent();
  s.isUploading=true;c.markFigureDirty();
  first.resolve({status:'completed',outputs:{preview:'old-example.png'}});
  await rendering;
  assert.equal(published.includes('old-example.png'),false);
  assert.notEqual(s.renderedRevision,s.revision);
});

test('schema numeric bounds and integer types survive normalization',()=>{
  const {context:c}=runtime();
  const controls=c.normalizeSchema({marks:{count:{type:'integer',default:2,min:1,max:6,step:1},angle:{type:'number',minimum:-90,maximum:90}}})[0].controls;
  assert.equal(controls[0].type,'integer');
  assert.equal(c.numberFieldMeta('count',controls[0]).max,6);
  assert.equal(c.numberFieldMeta('angle',controls[1]).min,-90);
  assert.equal(c.numberFieldMeta('x_axis_text_angle',{}).min,-360);
});

test('invalid numbers block rendering, keep the last valid value, and recover',async()=>{
  const {context:c,state:s}=runtime();
  s.autoUpdateEnabled=false;s.params={point_alpha:0.5};
  const field=c.renderInputForControl({key:'point_alpha',label:'Opacity',type:'number',min:0,max:1,step:0.1});
  const input=field.children[0];input.value='2';input.validity.valid=false;input.oninput();
  assert.equal(s.params.point_alpha,0.5);
  assert.equal(s.invalidFields.size,1);
  c.fetch=()=>assert.fail('invalid settings must not render');await c.runDemoSilent();
  input.value='0.7';input.validity.valid=true;input.oninput();
  assert.equal(s.params.point_alpha,0.7);assert.equal(s.invalidFields.size,0);
});

test('complex parameter editors preserve object/list types and reject malformed JSON',()=>{
  const {context:c,state:s}=runtime();s.autoUpdateEnabled=false;
  s.params={group_colors:{A:'#ff0000'}};
  const field=c.renderInputForControl({key:'group_colors',label:'Group colors',type:'object'});
  const input=field.children[0];input.value='{"B":"#00ff00"}';input.oninput();
  assert.equal(s.params.group_colors.B,'#00ff00');
  input.value='[';input.oninput();assert.equal(s.invalidFields.size,1);
  assert.equal(s.params.group_colors.B,'#00ff00');
});

test('advanced configuration rejects arrays, null, and invalid syntax',()=>{
  const {context:c,state:s,els}=runtime();
  s.params={title:'valid'};
  for(const value of ['[]','null','{']) {
    c.document.getElementById('paramsText').value=value;c.syncParamsFromJson();
    assert.equal(s.params.title,'valid');assert.equal(s.invalidFields.has('__json'),true);
  }
  els.get('paramsText').value='{"title":"fixed"}';c.syncParamsFromJson();
  assert.equal(s.params.title,'fixed');assert.equal(s.invalidFields.size,0);
});

test('exports stay unavailable while dirty or rendering and reappear only when synced',()=>{
  const {context:c,state:s,els}=runtime({downloads:true});
  c.normalizeOutputMap=out=>({png:out.png?{url:out.png}:undefined});
  const row=element();row.dataset.fmt='png';c.ensureExportItems=()=>[row];
  s.revision=2;s.renderedRevision=1;
  c.renderDownloads({png:'/old.png'});assert.equal(row.href,'#');
  s.renderedRevision=2;s.isUpdating=true;
  c.renderDownloads({png:'/new.png'});assert.equal(row.href,'#');
  s.isUpdating=false;c.renderDownloads({png:'/new.png'});
  assert.equal(row.href,'/new.png');
  assert.equal(els.get('exportMenuEmpty').hidden,true);
});

test('successful upload adopts the parsed file and resets selections from the previous dataset',async()=>{
  const {context:c,state:s,els}=runtime();
  s.params={rows_include:['old'],groups_include:['Old']};s.selectedRows.add('old');
  const data=new File(['x\n7\n'],'new.csv');
  c.fetch=async()=>({ok:true,json:async()=>({files:{input:{filename:'new.csv',columns:['x'],row_count_estimate:1,preview_rows:[{x:'7'}]}}})});
  await c.loadUserFile('input',data);
  assert.equal(s.customFiles.input,data);assert.equal(s.selectedRows.size,0);
  assert.equal(s.params.rows_include,undefined);assert.equal(s.params.groups_include,undefined);
  assert.match(els.get('dataSource').textContent,/Your data: new.csv.*1 rows/);
});

test('non-tabular secondary files remain usable even without a table preview',async()=>{
  const {context:c,state:s}=runtime();
  s.detail={inputs:[{id:'genesets',type:'file',required:true}]};
  const data=new File(['set\tdescription\tA\tB'],'pathways.gmt');
  c.fetch=async()=>({ok:true,json:async()=>({files:{genesets:{filename:'pathways.gmt',error:'Unsupported table type: .gmt'}}})});
  await c.loadUserFile('genesets',data);
  assert.equal(s.customFiles.genesets,data);
});

test('empty tables cannot replace a valid dataset',async()=>{
  const {context:c,state:s}=runtime();
  s.detail={inputs:[{id:'input',type:'table',required:true}]};
  c.fetch=async()=>({ok:true,json:async()=>({files:{input:{filename:'empty.csv',columns:['x'],row_count_estimate:0}}})});
  await c.loadUserFile('input',new File(['x\n'],'empty.csv'));
  assert.equal(Object.keys(s.customFiles).length,0);
});

test('valid JSON with invalid numeric values is blocked before rendering',async()=>{
  const {context:c,state:s,els}=runtime();
  s.params={width:-1};
  c.fetch=()=>assert.fail('must not render invalid numeric parameters');
  await c.runDemoSilent();assert.match(els.get('jobStatus').textContent,/width|Width/);
  s.params.width=6;assert.equal(c.numericValidationErrors().length,0);
});

test('choosing a preset updates the example preview and keeps explicitly uploaded data',async()=>{
  const {context:c,state:s}=runtime();
  const record={params:{title:'Preset'},input_preview:{files:{input:{filename:'example.csv'}}}};
  c.fetch=async()=>({ok:true,json:async()=>record});c.runDemoSilent=async()=>{};
  await c.loadPreset('basic');assert.equal(s.inputPreview.files.input.filename,'example.csv');
  const data=new File(['x\n9'],'mine.csv');s.customFiles={input:data};
  s.inputPreview={files:{input:{filename:'mine.csv'}}};
  await c.loadPreset('custom');assert.equal(s.customFiles.input,data);
  assert.equal(s.inputPreview.files.input.filename,'mine.csv');assert.equal(s.params.title,'Preset');
});

test('static images are the initial preview even when a fallback HTML exists',async()=>{
  const {context:c,state:s}=runtime();let html=false,image=false;
  // Use the real preview dispatcher, replacing only its display adapters.
  vm.runInContext(source.slice(source.indexOf('async function updateInstantPreview('),source.indexOf('\nasync function renderPlotlyPreview(')),c);
  c.updateHtmlPreview=()=>{html=true;};c.hideHtmlPreview=()=>{};
  c.renderPlotlyPreview=async()=>false;c.updatePreviewImage=()=>{image=true;};
  assert.equal(s.preferHtmlPreview,false);
  await c.updateInstantPreview({preview:'result.png',html:'fallback.html'});
  assert.equal(image,true);assert.equal(html,false);
});

test('switching datasets clears stale plugin-specific column mappings and feature selections',()=>{
  const {context:c,state:s}=runtime();
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../../static/data_mapping.js'),'utf8'),c);
  s.schemaSections=[{controls:[{key:'gene_column',type:'column'},{key:'pval_column',type:'column'}]}];
  s.params={gene_column:'old_gene',pval_column:'padj',features:['old_feature','new_feature']};
  s.inputPreview={files:{input:{columns:['gene','padj','new_feature']}}};
  c.reconcileMappingsWithDataset();
  assert.equal(s.params.gene_column,'');assert.equal(s.params.pval_column,'padj');
  assert.deepEqual(Array.from(s.params.features),['new_feature']);
});

test('bundled example preview does not submit a render and offers export generation',async()=>{
  const {context:c,state:s,els}=runtime({downloads:true});
  const urls=[],images=[];
  c.updatePreviewImage=url=>images.push(url);
  c.fetch=async url=>{urls.push(url);return {ok:true,json:async()=>({params:{title:'Example'},expected:'/example.png',input_preview:{files:{}}})};};
  await c.loadPreset('basic',{previewOnly:true});
  assert.equal(urls.length,1);assert.match(urls[0],/examples\/basic/);
  assert.deepEqual(images,['/example.png']);
  assert.equal(s.previewRevision,s.revision);assert.notEqual(s.renderedRevision,s.revision);
  assert.equal(els.get('prepareExportButton').disabled,false);
  assert.equal(els.get('prepareExportButton').hidden,false);
  assert.equal(els.get('editorStateText').textContent,'Example preview');
});

test('progressive preview preserves render lock until exports complete',async()=>{
  const {context:c,state:s,els}=runtime();
  s.isUpdating=true;let polls=0;const images=[];
  c.setTimeout=fn=>{fn();return 0;};c.updatePreviewImage=url=>images.push(url);
  c.fetch=async()=>({ok:true,json:async()=>++polls===1
    ?{status:'running',live_preview:'/partial.png'}:{status:'completed',outputs:{preview:'/final.png'}}});
  const result=await c.waitForRender({status:'queued',poll_url:'/api/jobs/one'},s.revision);
  assert.equal(result.status,'completed');assert.equal(s.isUpdating,true);
  assert.deepEqual(images,['/partial.png']);assert.equal(s.previewRevision,s.revision);
  assert.equal(els.get('stageOverlay').classList.contains('hidden'),true);
});

test('a poll response for obsolete settings cannot replace the preview',async()=>{
  const {context:c,state:s}=runtime();
  const response=deferred();c.fetch=async()=>({ok:true,json:async()=>response.promise});
  c.updatePreviewImage=()=>assert.fail('stale preview must not be shown');
  const waiting=c.waitForRender({status:'running',poll_url:'/api/jobs/old'},s.revision);
  s.revision++;response.resolve({status:'running',live_preview:'/old.png'});
  await waiting;assert.equal(s.previewRevision,-1);
});

test('settings changed while loading Plotly cannot publish an obsolete image',async()=>{
  const {context:c,state:s}=runtime();
  vm.runInContext(source.slice(source.indexOf('async function updateInstantPreview('),source.indexOf('\nasync function renderPlotlyPreview(')),c);
  const loading=deferred();c.renderPlotlyPreview=()=>loading.promise;
  c.hideHtmlPreview=()=>{};c.syncInteractiveToggle=()=>{};
  c.updatePreviewImage=()=>assert.fail('outdated image must not replace the current preview');
  const updating=c.updateInstantPreview({preview:'/old.png'});
  s.revision++;loading.resolve(false);await updating;
});

test('legend title control edits the declared parameter instead of a shadow alias',()=>{
  const {context:c}=runtime();
  c.controlsForTab=()=>[{key:'legend_title',type:'string',label:'Legend title',default:''}];
  const controls=c.mergeCommonWithSchema('legend');
  assert.equal(controls.filter(item=>item.key==='legend_title').length,1);
  assert.equal(controls.some(item=>item.key==='legend_name'),false);
});

test('published example cards show a paper link, provenance, and their runnable preset',()=>{
  const {context:c}=runtime();
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../../static/plot_guide.js'),'utf8'),c);
  const html=c.renderExamplesGuide({examples:[{id:'tf',title:'TF use case',demo_id:'CAB_demo',variant_id:'diverging_tf',
    literature_id:'paper',data_note:'Synthetic demonstration',description:'Use case <details>'}],
    literature:[{id:'paper',title:'Verified article',citation:'Authors, 2026',figure:'Figure 6L',url:'https://example.org/paper'}]});
  assert.match(html,/href="https:\/\/example.org\/paper"/);
  assert.match(html,/data-try-example="CAB_demo"/);assert.match(html,/data-try-variant="diverging_tf"/);
  assert.match(html,/Synthetic demonstration/);assert.match(html,/Figure 6L/);
  assert.match(html,/Use case &lt;details&gt;/);
});

test('guide mappings and customization are readable and escaped; method references stay labelled',()=>{
  const {context:c}=runtime();
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../../static/plot_guide.js'),'utf8'),c);
  const about=c.renderAboutGuide({available:true,name:'Line',family_guide:{input_requirements:'x < y',
    customization:[{parameter:'x_column',label:'X',default:'<sample>',help:'A & B'}]}});
  assert.match(about,/Input requirements/); assert.match(about,/x &lt; y/);
  assert.match(about,/<summary>Customization/);assert.match(about,/&lt;sample&gt;/);
  const examples=c.renderExamplesGuide({examples:[{demo_id:'basic',input_requirements:'A & B',mappings:{x_column:'<gene>'}}]});
  assert.match(examples,/Input and mappings/);assert.match(examples,/&lt;gene&gt;/);
  const literature=c.renderLiteratureGuide({literature:[{title:'Methods',reference_type:'method_reference'}]});
  assert.match(literature,/Method reference/);assert.match(literature,/not a reproduction/);
});

test('published panels precede demos and keep figure labels, adaptation and preprint status',()=>{
  const {context:c}=runtime();
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../../static/plot_guide.js'),'utf8'),c);
  const payload={examples:[{id:'basic',demo_id:'basic',title:'Local data'}],published_examples:[{
    figure:'Figure 6F',title:'Metric <matrix>',paper_title:'Benchmark',authors:'Authors',year:2026,
    journal:'bioRxiv',publication_status:'preprint',match_type:'related_layout',
    description:'Caption summary',adaptation:'Compute ranks & scores upstream',verified_on:'2026-10-25',
    figure_url:'https://example.org/paper#F6',paper_url:'https://example.org/paper',doi:'10.1234/test'}]};
  const html=c.renderExamplesGuide(payload);
  assert.ok(html.indexOf('Published figure examples') < html.indexOf('Local runnable demos'));
  assert.match(html,/Figure 6F/);assert.match(html,/Metric &lt;matrix&gt;/);
  assert.match(html,/Related layout · adaptation required/);assert.match(html,/Preprint \(not peer reviewed\)/);
  assert.match(html,/Compute ranks &amp; scores upstream/);assert.match(html,/View figure source/);
  assert.match(html,/data-try-example="basic"/);
  assert.match(c.renderLiteratureGuide({...payload,literature:[]}),/Figure 6F/);
});
