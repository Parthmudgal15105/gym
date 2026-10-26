(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.GymCore=api})(typeof window==='object'?window:globalThis,function(){
'use strict';
const parts=['Chest','Back','Tricep','Bicep','Legs','Shoulders','Abs'];
const units=['kg','kg each','kg/side','plates','bodyweight'];
const defaultNames={Chest:['Incline barbell bench press','Flat barbell bench press','Chest fly machine','Dumbbell chest press'],Back:['One-arm dumbbell row','Lat pulldown'],Tricep:['Triceps cable pushdown','Single-arm cable pushdown'],Bicep:['Seated dumbbell biceps curl','Seated hammer curl'],Legs:['Squat','Romanian deadlift','Leg extension'],Shoulders:['Seated Smith machine shoulder press','Seated lateral raise','Reverse pec deck','Face pull'],Abs:['Hanging leg raise']};
function templatesFrom(seed){const exercises=[...seed.sessions.flatMap(s=>s.exercises),...seed.review.flatMap(r=>r.exercises)];return Object.fromEntries(parts.map(m=>[m,defaultNames[m].map((name,i)=>{const e=exercises.find(e=>e.name===name);return {id:'default-'+m+'-'+i,name,unit:e?.sets[0]?.unit||'kg',notes:e?.pain?'Previously reported discomfort.':''}})]))}
function addDefaults(state,session,m){for(const t of state.templates[m]||[]){if(!session.exercises.some(e=>e.name.toLowerCase()===t.name.toLowerCase()))session.exercises.push({id:'exercise-'+(typeof crypto!=='undefined'?crypto.randomUUID():Math.random().toString(36).slice(2)),name:t.name,muscle:m,unit:t.unit,sets:[],notes:t.notes||'',pain:false,fromDefault:true})}}

const clone=x=>JSON.parse(JSON.stringify(x));
const dateKey=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
function validDate(s){if(typeof s!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(s))return false;const d=new Date(s+'T12:00:00');return !isNaN(d)&&dateKey(d)===s}
function normalizePart(m){return ({Triceps:'Tricep',Biceps:'Bicep',Core:'Abs'})[m]||m}
function sessionParts(s){return [...new Set([...s.muscles,...s.exercises.map(e=>e.muscle)].map(normalizePart))]}
function prepare(seed,legacy=[]){const state=clone(seed);state.importedSeeds=[seed.seedVersion];state.templates=templatesFrom(seed);for(const old of legacy){if(!old||!validDate(old.date)||!Array.isArray(old.muscles))continue;let s=state.sessions.find(s=>s.date===old.date);if(!s){s={id:old.id||'legacy-'+old.date,date:old.date,muscles:[],exercises:[],notes:'',source:'Calendar history'};state.sessions.push(s)}s.muscles=[...new Set([...s.muscles,...old.muscles.map(normalizePart)])];if(old.notes)s.notes=[s.notes,old.notes].filter(Boolean).join('\n');if(old.title&&!old.muscles.includes(old.title))s.legacyTitle=old.title;if(old.duration)s.duration=old.duration}return state}
function mergeLegacy(state,legacy){
 if(!Array.isArray(legacy))throw Error('Invalid legacy history');
 state.importedLegacyIds||=[];state.legacyRecords||=[];
 let added=0;
 for(const old of legacy){
  if(!old||!validDate(old.date)||!Array.isArray(old.muscles)||!old.muscles.every(m=>typeof m==='string'))throw Error('Invalid legacy record');
  const key=old.id||JSON.stringify(old);
  if(state.importedLegacyIds.includes(key))continue;
  const s=ensureSession(state,old.date);
  s.muscles=[...new Set([...s.muscles,...old.muscles.map(normalizePart)])];
  if(old.notes&&!s.notes.includes(old.notes))s.notes=[s.notes,old.notes].filter(Boolean).join('\n');
  if(old.duration)s.duration=(s.duration||0)+old.duration;
  state.legacyRecords.push(clone(old));state.importedLegacyIds.push(key);added++;
 }
 return added;
}
function ensureSession(state,date){let s=state.sessions.find(s=>s.date===date);if(!s){s={id:'day-'+date,date,muscles:[],exercises:[],notes:''};state.sessions.push(s)}return s}
function activeSessions(state,from='',to='9999-12-31'){return state.sessions.filter(s=>s.date>=from&&s.date<=to&&(sessionParts(s).length||s.exercises.length))}
const recordedSets=e=>e.sets.filter(t=>t.load!==null||t.reps!==null);
function summarize(state,from='',to='9999-12-31'){const ss=activeSessions(state,from,to);return {days:new Set(ss.map(s=>s.date)).size,sets:ss.reduce((n,s)=>n+s.exercises.reduce((a,e)=>a+recordedSets(e).length,0),0),exercises:ss.reduce((n,s)=>n+s.exercises.filter(e=>recordedSets(e).length).length,0),parts:Object.fromEntries(parts.map(p=>[p,new Set(ss.filter(s=>sessionParts(s).includes(p)).map(s=>s.date)).size])),missingReps:ss.reduce((n,s)=>n+s.exercises.reduce((a,e)=>a+recordedSets(e).filter(t=>t.reps===null).length,0),0)}}
function exerciseNames(state){return [...new Set(state.sessions.flatMap(s=>s.exercises.map(e=>e.name)))].sort()}
function exerciseHistory(state,name,unit,from='',to='9999-12-31'){return activeSessions(state,from,to).sort((a,b)=>a.date.localeCompare(b.date)).flatMap(s=>{const sets=s.exercises.filter(e=>e.name.toLowerCase()===name.toLowerCase()).flatMap(e=>e.sets).filter(t=>t.unit===unit&&t.reps!==null&&(unit==='bodyweight'||t.load!==null));if(!sets.length)return [];const best=[...sets].sort((a,b)=>unit==='bodyweight'?b.reps-a.reps:b.load-a.load||b.reps-a.reps)[0];return [{date:s.date,load:best.load,reps:best.reps,unit,sets:sets.length}]})}
function resolveReview(state,id,date){if(!validDate(date))throw Error('Choose a valid date.');const item=state.review.find(r=>r.id===id);if(!item||!item.exercises.length)throw Error('This report has no confirmed sets to assign.');if(item.resolvedDate)throw Error('This report has already been assigned.');const s=ensureSession(state,date);for(const recovered of clone(item.exercises)){const draft=s.exercises.find(e=>e.name===recovered.name&&!e.sets.length);if(draft){Object.assign(draft,recovered)}else{s.exercises.push(recovered)}}s.muscles=[...new Set([...s.muscles,...item.muscles])];s.notes=[s.notes,`Confirmed from report dated ${item.reportedDate}.`,item.notes].filter(Boolean).join('\n');item.resolvedDate=date;return s}
function validate(state){const fail=m=>{throw Error(m)};if(!state||state.version!==3||!Array.isArray(state.sessions)||!Array.isArray(state.review)||!state.profile||!Array.isArray(state.measurements))fail('Choose a Gym backup file.');const number=(n,min,max)=>n===null||(Number.isFinite(n)&&n>=min&&n<=max);const text=(s,max=4000)=>typeof s==='string'&&s.length<=max;const validExercise=e=>text(e.id,200)&&text(e.name,120)&&e.name.trim()&&parts.includes(e.muscle)&&text(e.notes)&&typeof e.pain==='boolean'&&Array.isArray(e.sets)&&e.sets.length<=100&&e.sets.every(t=>units.includes(t.unit)&&number(t.load,0,10000)&&number(t.reps,1,1000)&&(t.reps===null||Number.isInteger(t.reps)));
const seen=new Set();for(const s of state.sessions){if(!validDate(s.date)||seen.has(s.date)||!text(s.id,200)||!Array.isArray(s.muscles)||!s.muscles.every(m=>text(m,50))||!Array.isArray(s.exercises)||!s.exercises.every(validExercise)||!text(s.notes))fail('This backup contains an invalid workout.');seen.add(s.date)}
for(const r of state.review){if(!text(r.id,200)||!text(r.title,200)||!text(r.notes,20000)||!validDate(r.reportedDate)||!Array.isArray(r.exercises)||!r.exercises.every(validExercise)||(r.resolvedDate&&!validDate(r.resolvedDate)))fail('This backup contains an invalid report.')}
for(const m of state.measurements){if(!validDate(m.date)||!Number.isFinite(m.weight)||m.weight<20||m.weight>400||!['waist','arm'].every(k=>m[k]===null||(Number.isFinite(m[k])&&m[k]>0&&m[k]<=300)))fail('This backup contains an invalid measurement.')}
if(!number(state.profile.height,50,260)||!number(state.profile.baselineWeight,20,400)||!['goals','equipment','experience','painNote','baselineNote'].every(k=>text(state.profile[k])))fail('This backup contains an invalid profile.');if(state.templates&&(!parts.every(p=>Array.isArray(state.templates[p])&&state.templates[p].every(t=>text(t.id,200)&&text(t.name,120)&&t.name.trim()&&units.includes(t.unit)))))fail('This backup contains invalid exercise defaults.');return state}
return {parts,units,clone,mergeLegacy,recordedSets,templatesFrom,addDefaults,dateKey,validDate,normalizePart,sessionParts,prepare,ensureSession,activeSessions,summarize,exerciseNames,exerciseHistory,resolveReview,validate};
});
