(function(root){
  'use strict';
  const defaults={fromName:'Ralph Smits',fromAddress:'Alphensebaan 6\n4861 RA Chaam\nNoord-Brabant, Netherlands',toName:'Warni Smits-van Mierlo',toAddress:'Alphensebaan 6\n4861 RA Chaam\nNoord-Brabant, Netherlands',iban:'NL88 RABO 0116 6463 06',accountName:'W. van Mierlo',includeFixed:true};
  function create({jsPDF,month,trips=[],costs,details={},closed=false,issueDate=new Date()}){
    const info={...defaults,...details},doc=new jsPDF({unit:'mm',format:'a4'}),left=18,right=192,width=174;
    doc.addFileToVFS('Roadnote-Regular.ttf',root.RoadnoteInvoiceFonts.normal);doc.addFileToVFS('Roadnote-Bold.ttf',root.RoadnoteInvoiceFonts.bold);doc.addFont('Roadnote-Regular.ttf','Roadnote','normal');doc.addFont('Roadnote-Bold.ttf','Roadnote','bold');
    const ink=[24,32,48],muted=[90,108,135],blue=[38,99,235],line=[218,226,237];
    const euro=n=>`€ ${Number(n||0).toFixed(2)}`;
    const clean=v=>String(v??'').replace(/[\u0000-\u001f]/g,' ').replace(/→/g,' to ').replace(/[–—]/g,'-');
    const text=(value,x,y,size=10,bold=false,color=ink,align='left')=>{doc.setFont('Roadnote',bold?'bold':'normal');doc.setFontSize(size);doc.setTextColor(...color);doc.text(clean(value),x,y,{align});};
    doc.setProperties({title:`Invoice ${month}`,subject:'Monthly car journeys and costs',author:info.fromName,creator:'Roadnote'});
    text('FACTUUR',left,27,27,true,blue);
    text(`Invoice Number: INV-${month}-001`,right,22,9,false,muted,'right');
    text(`Date of Issue: ${issueDate.toLocaleDateString('en-GB',{month:'long',day:'numeric',year:'numeric'})}`,right,28,9,false,muted,'right');
    doc.setDrawColor(...blue);doc.setLineWidth(.45);doc.line(left,35,right,35);
    function party(label,name,address,x){text(label,x,49,9,true,muted);doc.setFont('Roadnote','bold');doc.setFontSize(11);const names=doc.splitTextToSize(clean(name),78);doc.setTextColor(...ink);doc.text(names,x,57);let y=57+names.length*5;doc.setFont('Roadnote','normal');doc.setFontSize(10);for(const part of String(address).split('\n')){const rows=doc.splitTextToSize(clean(part),78);doc.text(rows,x,y);y+=rows.length*5;}return y;}
    let y=Math.max(party('FROM',info.fromName,info.fromAddress,left),party('BILLED TO',info.toName,info.toAddress,114))+9;
    doc.setFillColor(247,249,252);doc.setDrawColor(...line);doc.roundedRect(left,y,width,11,1,1,'FD');
    text(`${new Date(`${month}-01T12:00:00`).toLocaleDateString('en-GB',{month:'long',year:'numeric'})} journeys · ${closed?'Closed period':'Open period'} · Fuel costs are estimates`,left+3,y+7,9,false,muted);
    const rows=trips.map(t=>[t.date,`${clean(t.destination)} (${t.returnTrip?'Return Trip':'Single Journey'})`,t.car==='karl'?'Karl':'Crossland',`${Number(t.distance).toFixed(1).replace(/\.0$/,'')} km`,euro(t.cost)]);
    doc.autoTable({startY:y+19,margin:{left,right:18,top:25,bottom:24},head:[['Date','Destination','Vehicle','Distance','Cost']],body:rows.length?rows:[[{content:'No journeys recorded for this month.',colSpan:5}]],theme:'plain',styles:{font:'Roadnote',fontSize:9.5,textColor:ink,cellPadding:{top:3.5,right:2.5,bottom:3.5,left:2.5},lineColor:line,lineWidth:{bottom:.2},overflow:'linebreak'},headStyles:{fillColor:[242,245,249],fontStyle:'bold',textColor:[53,70,94],lineWidth:{bottom:.4}},columnStyles:{0:{cellWidth:28},1:{cellWidth:62},2:{cellWidth:28},3:{cellWidth:28,halign:'right'},4:{cellWidth:28,halign:'right'}},rowPageBreak:'avoid',showHead:'everyPage',willDrawPage:()=>{if(doc.getNumberOfPages()>1){text('FACTUUR',left,15,14,true,blue);text(`INV-${month}-001 · continued`,right,15,9,false,muted,'right');}}});
    y=doc.lastAutoTable.finalY+9;
    const tax=info.includeFixed?Number(costs.tax||0):0,insurance=info.includeFixed?Number(costs.insurance||0):0,total=Number(costs.fuel||0)+tax+insurance;
    const summary=[['Fuel subtotal',costs.fuel],...(info.includeFixed?[['Road tax',tax],['Insurance',insurance]]:[])];
    const needed=summary.length*7+20+39;
    if(y+needed>267){doc.addPage();y=31;text('FACTUUR',left,17,16,true,blue);text(`INV-${month}-001`,right,17,9,false,muted,'right');}
    for(const [label,amount] of summary){text(label,108,y+4,10);text(euro(amount),right-2,y+4,10,false,ink,'right');y+=7;}
    doc.setDrawColor(...ink);doc.setLineWidth(.35);doc.line(105,y+1,right,y+1);text('Total Due',108,y+9,12,true);text(euro(total),right-2,y+9,12,true,ink,'right');y+=26;
    text('Payment Instructions:',left,y,10,true,muted);y+=6;
    text(`Please transfer the total amount of ${euro(total)} to:`,left,y,10,false,muted);y+=6;
    for(const value of [`IBAN: ${info.iban}`,`Account Name: ${info.accountName}`,'Thank you!']){doc.setFont('Roadnote','normal');doc.setFontSize(10);const lines=doc.splitTextToSize(clean(value),width);doc.setTextColor(...muted);doc.text(lines,left,y);y+=lines.length*5.5;}
    const pages=doc.getNumberOfPages();for(let page=1;page<=pages;page++){doc.setPage(page);doc.setDrawColor(...line);doc.setLineWidth(.25);doc.line(left,277,right,277);text('Generated via Roadnote · Car Journeys App Data',left,284,8,false,muted);text(`Page ${page} of ${pages}`,right,284,8,false,muted,'right');}
    return doc;
  }
  root.RoadnoteInvoice={defaults,create};
  if(typeof module==='object')module.exports=root.RoadnoteInvoice;
})(typeof window==='undefined'?globalThis:window);
