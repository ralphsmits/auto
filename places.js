(function(root){
  'use strict';
  function read(value){
    const raw=String(value||'');
    try{const p=JSON.parse(raw);if(p?.roadnote_place===1&&typeof p.address==='string')return {address:p.address,name:typeof p.name==='string'?p.name:null};}catch{}
    return {address:raw,name:null};
  }
  function compact(value){
    const parts=String(value||'').split(',').map(v=>v.trim()).filter(Boolean);
    let label=parts[0]||'';
    if(/^\d+[a-z]?(?:[-/]\d+[a-z]?)?$/i.test(label)&&parts[1])label=`${parts[1]} ${label}`;
    return label.length>60?label.slice(0,57)+'…':label;
  }
  function display(value,preferences={}){
    const parsed=read(value);if(parsed.name)return parsed.name;
    const normalize=v=>String(v||'').trim().toLocaleLowerCase();
    const match=[preferences.defaultOrigin,...(preferences.favorites||[])].filter(Boolean).find(p=>normalize(p.label)===normalize(parsed.address));
    return match?.name||compact(parsed.address);
  }
  function pack(point,input){
    if(point?.label&&point.name===input)return JSON.stringify({roadnote_place:1,name:point.name,address:point.label});
    return String(input||'').trim();
  }
  root.RoadnotePlaces={read,compact,display,pack};
  if(typeof module==='object')module.exports=root.RoadnotePlaces;
})(typeof window==='undefined'?globalThis:window);
