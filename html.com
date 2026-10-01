<!DOCTYPE html>
<html lang="ne">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mero QR</title>
<style>
:root{--bg:#f6f7f9;--card:#fff;--tx:#161a20;--mu:#6b7380;--ac:#4f46e5;--bd:#e3e6eb}
@media (prefers-color-scheme:dark){:root{--bg:#111317;--card:#1b1e24;--tx:#eef0f3;--mu:#99a1ad;--ac:#8b86ff;--bd:#2b3038}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);font:16px system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
main{max-width:560px;margin:0 auto;padding:20px 16px 40px}
h1{font-size:22px;margin:4px 0 2px}
p.s{color:var(--mu);margin:0 0 18px;font-size:14px}
.list{display:grid;gap:10px}
.item{display:flex;justify-content:space-between;width:100%;padding:16px;background:var(--card);border:1px solid var(--bd);border-radius:12px;color:var(--tx);font-size:17px;font-weight:600;cursor:pointer;text-align:left}
.item:hover{border-color:var(--ac)}
.item span{color:var(--mu);font-weight:400;font-size:13px}
.empty{color:var(--mu);text-align:center;padding:28px 0}
.panel{margin-top:22px;padding:16px;background:var(--card);border:1px solid var(--bd);border-radius:12px;display:grid;gap:10px}
.panel h2{margin:0;font-size:16px}
input[type=text]{padding:12px;border:1px solid var(--bd);border-radius:10px;background:var(--bg);color:var(--tx);font-size:16px;width:100%}
input[type=file]{font-size:14px;color:var(--mu);max-width:100%}
button.p{padding:12px;border:0;border-radius:10px;background:var(--ac);color:#fff;font-size:16px;font-weight:600;cursor:pointer}
button.p:disabled{opacity:.6}
.lnk{background:none;border:0;color:var(--mu);font-size:13px;cursor:pointer;margin-top:18px;text-decoration:underline;padding:0}
.modal{position:fixed;inset:0;background:rgba(0,0,0,.6);display:none;align-items:center;justify-content:center;padding:16px;z-index:5}
.modal.on{display:flex}
.box{background:var(--card);border-radius:16px;padding:18px;max-width:420px;width:100%;text-align:center;max-height:100%;overflow:auto}
.box h3{margin:0 0 12px}
.box img{width:100%;max-width:340px;background:#fff;border-radius:10px}
.row{display:flex;gap:10px;margin-top:14px}
.row button{flex:1;padding:11px;border-radius:10px;border:1px solid var(--bd);background:var(--bg);color:var(--tx);font-size:15px;cursor:pointer}
.row .d{color:#d33;display:none}
.edit .row .d{display:block}
.hide{display:none}
</style>
</head>
<body>
<main>
  <h1>Mero QR haru</h1>
  <p class="s">Name ma click garnus, QR khulchha.</p>
  <div class="list" id="list"><div class="empty">Load hudai chha...</div></div>

  <div class="panel hide" id="addp">
    <h2>Naya QR thapnus</h2>
    <input type="text" id="name" list="sug" placeholder="Name (jastai: eSewa, Nabil Bank)">
    <datalist id="sug"><option>eSewa</option><option>Khalti</option><option>IME Pay</option><option>Fonepay</option><option>Nabil Bank</option><option>NIC Asia</option><option>Global IME Bank</option></datalist>
    <input type="file" id="file" accept="image/*">
    <button class="p" id="save">Save garnus</button>
  </div>

  <button class="lnk" id="toggle">Edit (passcode)</button>
</main>

<div class="modal" id="modal">
  <div class="box">
    <h3 id="mt"></h3>
    <img id="mi" alt="QR">
    <div class="row"><button id="close">Banda</button><button class="d" id="del">Delete</button></div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js"></script>
<script>
const SUPABASE_URL='https://pkbdygfdkeplutnzqjvx.supabase.co';
const SUPABASE_KEY='sb_publishable_tXcS8w9cY6TozitgxxswmA_tPkKXf1p';
const sb=supabase.createClient(SUPABASE_URL,SUPABASE_KEY);
const $=id=>document.getElementById(id);
let items=[],cur=null,pin=null;

const pub=p=>sb.storage.from('qrs').getPublicUrl(p).data.publicUrl;

async function load(){
  const {data,error}=await sb.from('qrs').select('*').order('created_at');
  if(error){$('list').innerHTML='<div class="empty">Load garna sakiyena: '+error.message+'</div>';return}
  items=data;render();
}
function render(){
  const l=$('list');l.innerHTML='';
  if(!items.length){l.innerHTML='<div class="empty">Kei QR chhaina.</div>';return}
  items.forEach(it=>{
    const b=document.createElement('button');b.className='item';
    b.innerHTML='<b></b><span>QR herna ›</span>';b.firstChild.textContent=it.name;
    b.onclick=()=>{cur=it;$('mt').textContent=it.name;$('mi').src=pub(it.path);$('modal').classList.add('on')};
    l.appendChild(b);
  });
}
function setEdit(on){
  $('addp').classList.toggle('hide',!on);
  document.body.classList.toggle('edit',on);
  $('toggle').textContent=on?'Edit band garnus':'Edit (passcode)';
  if(!on)pin=null;
}
$('toggle').onclick=async()=>{
  if(pin){setEdit(false);return}
  const p=prompt('Passcode halnus:');
  if(!p)return;
  const {data,error}=await sb.rpc('check_pin',{p_pin:p});
  if(error){alert('Error: '+error.message);return}
  if(!data){alert('Passcode galat chha.');return}
  pin=p;setEdit(true);
};
$('close').onclick=()=>$('modal').classList.remove('on');
$('modal').onclick=e=>{if(e.target===$('modal'))$('modal').classList.remove('on')};

$('del').onclick=async()=>{
  if(!cur||!pin||!confirm('Delete garne?'))return;
  const {error}=await sb.rpc('delete_qr',{p_pin:pin,p_id:cur.id});
  if(error){alert(error.message);return}
  $('modal').classList.remove('on');load();
};

function shrink(file){
  return new Promise((res,rej)=>{
    const im=new Image();
    im.onload=()=>{
      const s=Math.min(1,900/Math.max(im.width,im.height)),c=document.createElement('canvas');
      c.width=im.width*s;c.height=im.height*s;
      const x=c.getContext('2d');x.fillStyle='#fff';x.fillRect(0,0,c.width,c.height);x.drawImage(im,0,0,c.width,c.height);
      c.toBlob(b=>b?res(b):rej(new Error('Image convert bhayena')),'image/jpeg',.9);
    };
    im.onerror=()=>rej(new Error('Image padhna sakiyena'));
    im.src=URL.createObjectURL(file);
  });
}
$('save').onclick=async()=>{
  const n=$('name').value.trim(),f=$('file').files[0];
  if(!pin){alert('Pahile passcode halnus.');return}
  if(!n||!f){alert('Name ra QR image duitai chahinchha.');return}
  const btn=$('save');btn.disabled=true;btn.textContent='Upload hudai chha...';
  try{
    const blob=await shrink(f),path=crypto.randomUUID()+'.jpg';
    let r=await sb.storage.from('qrs').upload(path,blob,{contentType:'image/jpeg'});
    if(r.error)throw r.error;
    r=await sb.rpc('add_qr',{p_pin:pin,p_name:n,p_path:path});
    if(r.error)throw r.error;
    $('name').value='';$('file').value='';load();
  }catch(e){alert('Error: '+e.message)}
  btn.disabled=false;btn.textContent='Save garnus';
};
load();
</script>
</body>
</html>
