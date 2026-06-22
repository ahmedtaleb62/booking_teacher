import React, { useState, useEffect, useRef } from 'react'
import { supabase } from '../supabase'

const LEVELS = [
  { group: 'ابتدائية', items: ['سنة أولى ابتدائي','سنة ثانية ابتدائي','سنة ثالثة ابتدائي','سنة رابعة ابتدائي','سنة خامسة ابتدائي','سنة سادسة (Concours)'] },
  { group: 'إعدادية',  items: ['سنة أولى إعدادي','سنة ثانية إعدادي','سنة ثالثة إعدادي','سنة رابعة (Brevet)'] },
  { group: 'ثانوية',   items: ['سنة خامسة ثانوي','سنة سادسة ثانوي','BAC C','BAC D','BAC LO','BAC LA','BAC TGM'] },
]
const SUBJECTS = ['العربية','الفرنسية','الإنجليزية','الرياضيات','التاريخ و الجغرافيا','الفلسفة','العلوم الطبيعية','التربية الإسلامية','التربية المدنية']
const LTYPES   = [{ id:'video',icon:'🎬',label:'فيديو'},{id:'file',icon:'📄',label:'ملف'},{id:'exercise',icon:'📝',label:'تمرين'},{id:'summary',icon:'📋',label:'ملخّص'}]
const uid      = () => Math.random().toString(36).slice(2)
const newLesson  = () => ({ id:uid(), title:'', type:'video', url:'', file:null, uploadUrl:'', isPreview:false, exerciseKind:'file', quizQuestions:[], duration:'', pages:'' })
const newChapter = n  => ({ id:uid(), title:'الفصل '+n, expanded:true, lessons:[newLesson()] })
const newQuestion= () => ({ id:uid(), text:'', answers:['',''], correct:0 })

async function uploadFile(bucket, file) {
  const ext  = file.name.split('.').pop() || 'bin'
  const path = Date.now() + '_' + uid() + '.' + ext
  const { error } = await supabase.storage.from(bucket).upload(path, file, { upsert:true })
  if (error) throw error
  return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl
}

/* ── Quiz Builder ─────────────────────────────────── */
function QuizBuilder({ questions, onChange }) {
  const setQ   = (i, u)      => onChange(questions.map((q,j) => j===i ? {...q,...u} : q))
  const setAns = (qi, ai, v) => { const a=[...questions[qi].answers]; a[ai]=v; setQ(qi,{answers:a}) }
  return (
    <div style={{display:'flex',flexDirection:'column',gap:12}}>
      {questions.map((q, qi) => (
        <div key={q.id} style={{border:'1px solid #E1E9EF',borderRadius:11,overflow:'hidden'}}>
          <div style={{display:'flex',alignItems:'center',gap:10,padding:'9px 13px',background:'#F7F9FA',borderBottom:'1px solid #EFF2F4'}}>
            <span style={{width:25,height:25,borderRadius:7,background:'#7B61FF',color:'#fff',display:'flex',alignItems:'center',justifyContent:'center',fontSize:11,fontWeight:700,flexShrink:0}}>{qi+1}</span>
            <input className="field-input" style={{flex:1,fontSize:13,border:'none',background:'transparent',padding:0}} placeholder={'السؤال '+(qi+1)+'…'} value={q.text} onChange={e=>setQ(qi,{text:e.target.value})} />
            <button onClick={()=>onChange(questions.filter((_,j)=>j!==qi))} style={{background:'none',border:'none',cursor:'pointer',color:'#E57373',fontSize:15}}>🗑</button>
          </div>
          <div style={{padding:'11px 13px',display:'flex',flexDirection:'column',gap:7}}>
            {q.answers.map((ans, ai) => (
              <div key={ai} style={{display:'flex',alignItems:'center',gap:8}}>
                <input type="radio" name={'q-'+q.id} checked={q.correct===ai} onChange={()=>setQ(qi,{correct:ai})} style={{accentColor:'#1B9E77',width:15,height:15,cursor:'pointer',flexShrink:0}} />
                <input className="field-input" style={{flex:1,fontSize:12.5,padding:'6px 10px'}} placeholder={'الإجابة '+(ai+1)+'…'} value={ans} onChange={e=>setAns(qi,ai,e.target.value)} />
                {q.answers.length>2 && <button onClick={()=>{const a=q.answers.filter((_,j)=>j!==ai);setQ(qi,{answers:a,correct:Math.min(q.correct,a.length-1)})}} style={{background:'none',border:'none',cursor:'pointer',color:'#C0C9D2',fontSize:14}}>✕</button>}
              </div>
            ))}
            <div style={{display:'flex',justifyContent:'space-between',marginTop:4}}>
              <span style={{fontSize:10.5,color:'var(--text3)'}}>● = الإجابة الصحيحة</span>
              {q.answers.length<5 && <button onClick={()=>setQ(qi,{answers:[...q.answers,'']})} style={{fontSize:11.5,fontWeight:700,color:'#7B61FF',background:'none',border:'none',cursor:'pointer'}}>+ إجابة</button>}
            </div>
          </div>
        </div>
      ))}
      <button onClick={()=>onChange([...questions,newQuestion()])} style={{display:'flex',alignItems:'center',justifyContent:'center',gap:6,border:'1.5px dashed #C0C9D2',borderRadius:9,padding:10,fontSize:12.5,fontWeight:700,color:'#7B61FF',background:'transparent',cursor:'pointer',fontFamily:'inherit'}}>
        + إضافة سؤال
      </button>
    </div>
  )
}

/* ── Drop Zone ────────────────────────────────────── */
function DropZone({ accept, icon, hint, file, existingUrl, onChange }) {
  const [drag, setDrag] = useState(false)
  const ref = useRef()
  const hasExisting = !file && !!existingUrl
  const existingName = existingUrl ? decodeURIComponent(existingUrl.split('/').pop().split('?')[0]) : ''
  const active = file || hasExisting
  return (
    <div
      onDragOver={e=>{e.preventDefault();setDrag(true)}}
      onDragLeave={()=>setDrag(false)}
      onDrop={e=>{e.preventDefault();setDrag(false);const f=e.dataTransfer.files?.[0];if(f)onChange(f)}}
      onClick={()=>ref.current?.click()}
      style={{border:'2px dashed '+(drag?'var(--primary)':active?'#1B9E77':'#C9D3DC'),borderRadius:11,padding:'14px 16px',display:'flex',alignItems:'center',gap:12,cursor:'pointer',background:drag?'var(--primary-light)':active?'#F0FBF7':'#FAFBFC',transition:'all .15s'}}>
      <span style={{fontSize:26,flexShrink:0}}>{active?'✅':icon}</span>
      <div style={{flex:1,minWidth:0}}>
        <div style={{fontSize:12.5,fontWeight:700,color:active?'#15805F':'var(--text2)',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>
          {file ? file.name : hasExisting ? existingName : 'اختر أو اسحب ملفاً هنا'}
        </div>
        <div style={{fontSize:11,color:active?'#1B9E77':'var(--text3)',marginTop:2}}>
          {hasExisting ? 'ملف محفوظ — انقر لاستبداله' : hint}
        </div>
      </div>
      {file && <button onClick={e=>{e.stopPropagation();onChange(null)}} style={{background:'none',border:'none',cursor:'pointer',color:'#C0C9D2',fontSize:16}}>✕</button>}
      <input ref={ref} type="file" accept={accept} style={{display:'none'}} onChange={e=>onChange(e.target.files?.[0]||null)} />
    </div>
  )
}

/* ── Lesson Item ──────────────────────────────────── */
const LTYPE_COLORS = { video:'#1B6B7A', file:'#7B61FF', exercise:'#C77A1A', summary:'#15805F' }
const LTYPE_BG    = { video:'#E7F1F2', file:'#F0EDFF', exercise:'#FEF3E2', summary:'#E3F6EF' }

function LessonItem({ lesson, ci, li, onUpdate, onDelete }) {
  const [collapsed, setCollapsed] = useState(false)
  const [confirmDel, setConfirmDel] = useState(false)
  const set = f => onUpdate(ci, li, {...lesson,...f})
  const col = LTYPE_COLORS[lesson.type] || '#555'
  const bg  = LTYPE_BG[lesson.type]    || '#F5F5F5'

  return (
    <div style={{borderRadius:12,overflow:'hidden',background:'#fff',border:'1.5px solid #E4EBF0',boxShadow:'0 1px 4px rgba(0,0,0,.04)'}}>
      {/* ─ Header: always-visible editable row ─ */}
      <div style={{display:'flex',alignItems:'center',gap:8,padding:'10px 12px',background:'#F8FAFB',borderBottom:collapsed?'none':'1.5px solid #EDF1F4',flexWrap:'wrap'}}>
        {/* Title — always an input */}
        <input
          className="field-input"
          value={lesson.title}
          placeholder="عنوان الدرس…"
          onChange={e=>set({title:e.target.value})}
          style={{flex:'1 1 200px',fontSize:13,fontWeight:600,padding:'6px 10px',minWidth:0}}
        />
        {/* Duration / pages */}
        <div style={{display:'flex',alignItems:'center',gap:4,flexShrink:0}}>
          <input
            type="number" min="0" placeholder="0"
            value={lesson.type==='file'?(lesson.pages||''):(lesson.duration||'')}
            onChange={e=>lesson.type==='file'?set({pages:e.target.value}):set({duration:e.target.value})}
            style={{width:50,padding:'6px 7px',borderRadius:8,border:'1.5px solid #D6DFE6',fontSize:12,fontWeight:700,textAlign:'center',fontFamily:'inherit'}}
          />
          <span style={{fontSize:11,color:'#8A96A3'}}>{lesson.type==='file'?'ص':'د'}</span>
        </div>
        {/* Preview toggle */}
        <label style={{display:'flex',alignItems:'center',gap:5,cursor:'pointer',userSelect:'none',padding:'5px 10px',borderRadius:20,border:'1.5px solid '+(lesson.isPreview?'#1B9E77':'#DDE3E8'),background:lesson.isPreview?'#E3F6EF':'#fff',color:lesson.isPreview?'#15805F':'#8A96A3',fontSize:11.5,fontWeight:700,flexShrink:0}}>
          <input type="checkbox" checked={lesson.isPreview} onChange={e=>set({isPreview:e.target.checked})} style={{display:'none'}} />
          {lesson.isPreview?'✓ مجاني':'مجاني'}
        </label>
        {/* Collapse */}
        <button onClick={()=>setCollapsed(c=>!c)} title={collapsed?'عرض خيارات الدرس':'طي'} style={{width:30,height:30,borderRadius:8,border:'1.5px solid #D6DFE6',background:'#fff',color:'#8A96A3',fontSize:13,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,transition:'transform .15s',transform:collapsed?'rotate(180deg)':'none'}}>▲</button>
        {/* Delete */}
        {confirmDel
          ? <div style={{display:'flex',gap:5,flexShrink:0}}>
              <button onClick={()=>onDelete(ci,li)} style={{padding:'5px 11px',borderRadius:8,border:'none',background:'#DC2626',color:'#fff',fontSize:12,fontWeight:700,cursor:'pointer',fontFamily:'inherit'}}>تأكيد</button>
              <button onClick={()=>setConfirmDel(false)} style={{padding:'5px 11px',borderRadius:8,border:'1.5px solid #DDE3E8',background:'#fff',color:'#516170',fontSize:12,fontWeight:700,cursor:'pointer',fontFamily:'inherit'}}>إلغاء</button>
            </div>
          : <button onClick={()=>setConfirmDel(true)} style={{padding:'5px 10px',borderRadius:8,border:'1.5px solid #FCA5A5',background:'#FEF2F2',color:'#DC2626',fontSize:12,fontWeight:700,cursor:'pointer',fontFamily:'inherit',flexShrink:0}}>🗑</button>
        }
      </div>

      {/* ─ Body: type selector + content fields ─ */}
      {!collapsed && (
        <div style={{padding:'14px 14px 16px'}}>
          {/* Type selector */}
          <div style={{display:'grid',gridTemplateColumns:'repeat(4,1fr)',gap:7,marginBottom:14}}>
            {LTYPES.map(t=>{
              const sel=lesson.type===t.id
              return <button key={t.id} onClick={()=>set({type:t.id})}
                style={{display:'flex',flexDirection:'column',alignItems:'center',gap:4,padding:'9px 4px',borderRadius:10,border:'2px solid '+(sel?LTYPE_COLORS[t.id]:'#DDE3E8'),background:sel?LTYPE_BG[t.id]:'#FAFBFC',color:sel?LTYPE_COLORS[t.id]:'#7A8FA0',fontWeight:700,fontSize:11.5,cursor:'pointer',fontFamily:'inherit',transition:'all .12s'}}>
                <span style={{fontSize:19}}>{t.icon}</span>{t.label}
              </button>
            })}
          </div>

          {/* Video */}
          {lesson.type==='video' && (
            <div style={{display:'flex',flexDirection:'column',gap:10}}>
              <div>
                <div className="field-label" style={{marginBottom:6}}>🔗 رابط الفيديو (YouTube / Vimeo / مباشر)</div>
                <input className="field-input" dir="ltr" placeholder="https://youtube.com/watch?v=..." value={lesson.url} onChange={e=>set({url:e.target.value,uploadUrl:''})} style={{fontSize:12.5}} />
              </div>
              <div style={{textAlign:'center',fontSize:12,color:'#A0B4BE',fontWeight:700}}>— أو رفع ملف فيديو مباشرة —</div>
              <DropZone accept="video/*" icon="🎬" hint="MP4، MOV — حتى 500 MB" file={lesson.file} existingUrl={lesson.uploadUrl&&!lesson.url?lesson.uploadUrl:null} onChange={f=>set({file:f,url:'',uploadUrl:''})} />
            </div>
          )}

          {/* File / Summary */}
          {(lesson.type==='file'||lesson.type==='summary') && (
            <DropZone
              accept=".pdf,.doc,.docx,.ppt,.pptx"
              icon={lesson.type==='summary'?'📋':'📄'}
              hint="PDF، Word، PowerPoint"
              file={lesson.file}
              existingUrl={lesson.uploadUrl||null}
              onChange={f=>set({file:f,uploadUrl:''})}
            />
          )}

          {/* Exercise */}
          {lesson.type==='exercise' && (
            <>
              <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8,marginBottom:12}}>
                {[{id:'file',icon:'📄',label:'ملف تمرين',sub:'PDF أو Word'},{id:'quiz',icon:'❓',label:'كويز',sub:'أسئلة متعددة'}].map(k=>{
                  const sel=lesson.exerciseKind===k.id
                  return <button key={k.id} onClick={()=>set({exerciseKind:k.id})}
                    style={{display:'flex',alignItems:'center',gap:9,padding:'11px 12px',borderRadius:10,border:'2px solid '+(sel?'#C77A1A':'#DDE3E8'),background:sel?'#FEF3E2':'#FAFBFC',color:sel?'#C77A1A':'#516170',fontWeight:700,fontSize:12.5,cursor:'pointer',fontFamily:'inherit',transition:'all .12s'}}>
                    <span style={{fontSize:20}}>{k.icon}</span><div><div>{k.label}</div><div style={{fontSize:10.5,fontWeight:400,color:sel?'#A0682A':'#A0B4BE'}}>{k.sub}</div></div>
                  </button>
                })}
              </div>
              {lesson.exerciseKind==='file'
                ? <DropZone accept=".pdf,.doc,.docx" icon="📝" hint="PDF أو Word" file={lesson.file} existingUrl={lesson.uploadUrl||null} onChange={f=>set({file:f,uploadUrl:''})} />
                : <QuizBuilder questions={lesson.quizQuestions} onChange={q=>set({quizQuestions:q})} />
              }
            </>
          )}
        </div>
      )}
    </div>
  )
}

/* ── Chapter Block ────────────────────────────────── */
function ChapterBlock({ chapter, idx, onUpdate, onDelete, onLessonUpdate, onLessonDelete, onAddLesson }) {
  const [editTitle, setEditTitle] = useState(false)
  const [confirmDel, setConfirmDel] = useState(false)
  const titleRef = useRef()
  useEffect(()=>{ if(editTitle && titleRef.current) titleRef.current.focus() },[editTitle])
  const upd = f => onUpdate(idx, {...chapter,...f})

  return (
    <div style={{borderRadius:16,overflow:'hidden',border:'2px solid #D0DBE6',boxShadow:'0 2px 10px rgba(0,0,0,.05)'}}>
      <div style={{display:'flex',alignItems:'center',gap:12,padding:'14px 16px',background:chapter.expanded?'#1B6B7A':'#244B55',cursor:'pointer'}} onClick={()=>upd({expanded:!chapter.expanded})}>
        <span style={{width:38,height:38,borderRadius:11,background:'rgba(255,255,255,.18)',color:'#fff',display:'flex',alignItems:'center',justifyContent:'center',fontWeight:800,fontSize:16,flexShrink:0}}>{idx+1}</span>
        {editTitle
          ? <input ref={titleRef} className="field-input"
              style={{flex:1,fontWeight:700,fontSize:14,padding:'7px 11px',background:'rgba(255,255,255,.15)',border:'1.5px solid rgba(255,255,255,.4)',color:'#fff',borderRadius:9}}
              value={chapter.title} placeholder="اسم الفصل…"
              onChange={e=>upd({title:e.target.value})}
              onBlur={()=>setEditTitle(false)}
              onKeyDown={e=>{if(e.key==='Enter')setEditTitle(false);e.stopPropagation()}}
              onClick={e=>e.stopPropagation()} />
          : <span style={{flex:1,fontWeight:700,fontSize:15,color:'#fff'}}>{chapter.title}</span>
        }
        <span style={{padding:'3px 10px',borderRadius:20,background:'rgba(255,255,255,.15)',color:'rgba(255,255,255,.9)',fontSize:12,fontWeight:700,flexShrink:0}}>{chapter.lessons.length} درس</span>
        <div style={{display:'flex',gap:7,flexShrink:0}} onClick={e=>e.stopPropagation()}>
          <button onClick={()=>setEditTitle(true)} style={{display:'flex',alignItems:'center',gap:5,padding:'7px 13px',borderRadius:9,border:'1.5px solid rgba(255,255,255,.4)',background:'rgba(255,255,255,.12)',color:'#fff',fontSize:12.5,fontWeight:700,cursor:'pointer',fontFamily:'inherit',whiteSpace:'nowrap'}}>✏️ تعديل الاسم</button>
          {confirmDel
            ? <div style={{display:'flex',gap:6}}>
                <button onClick={()=>onDelete(idx)} style={{padding:'7px 14px',borderRadius:9,border:'none',background:'#DC2626',color:'#fff',fontSize:12.5,fontWeight:700,cursor:'pointer',fontFamily:'inherit',whiteSpace:'nowrap'}}>✓ تأكيد الحذف</button>
                <button onClick={()=>setConfirmDel(false)} style={{padding:'7px 14px',borderRadius:9,border:'1.5px solid rgba(255,255,255,.35)',background:'rgba(255,255,255,.1)',color:'#fff',fontSize:12.5,fontWeight:700,cursor:'pointer',fontFamily:'inherit'}}>إلغاء</button>
              </div>
            : <button onClick={()=>setConfirmDel(true)} style={{display:'flex',alignItems:'center',gap:5,padding:'7px 13px',borderRadius:9,border:'1.5px solid #FCA5A5',background:'rgba(220,38,38,.18)',color:'#FCA5A5',fontSize:12.5,fontWeight:700,cursor:'pointer',fontFamily:'inherit',whiteSpace:'nowrap'}}>🗑 حذف الفصل</button>
          }
          <button onClick={()=>upd({expanded:!chapter.expanded})} style={{width:36,height:36,borderRadius:9,border:'1.5px solid rgba(255,255,255,.3)',background:'rgba(255,255,255,.1)',color:'#fff',fontSize:14,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',transform:chapter.expanded?'rotate(180deg)':'none',transition:'transform .2s'}}>▼</button>
        </div>
      </div>

      {chapter.expanded && (
        <div style={{padding:'16px',display:'flex',flexDirection:'column',gap:10,background:'#F4F7F9'}}>
          {chapter.lessons.length===0 && (
            <div style={{textAlign:'center',padding:'20px 0',color:'#8A96A3',fontSize:13}}>لا توجد دروس بعد — انقر الزر أدناه لإضافة أول درس</div>
          )}
          {chapter.lessons.map((l, li) =>
            <LessonItem key={l.id} lesson={l} ci={idx} li={li} onUpdate={onLessonUpdate} onDelete={onLessonDelete} />
          )}
          <button onClick={()=>onAddLesson(idx)} style={{display:'flex',alignItems:'center',justifyContent:'center',gap:8,padding:'13px 0',borderRadius:11,background:'#1B6B7A',color:'#fff',border:'none',fontSize:13.5,fontWeight:700,cursor:'pointer',fontFamily:'inherit',boxShadow:'0 2px 8px rgba(27,107,122,.3)',transition:'opacity .15s'}}>
            ＋ إضافة درس جديد في هذا الفصل
          </button>
        </div>
      )}
    </div>
  )
}

/* ── Main Page ────────────────────────────────────── */
export default function AddCourse({ onNavigate, courseId }) {
  const isEdit = !!courseId

  const [form, setForm]         = useState({title:'',description:'',subject:'',level:'',priceMonthly:'',priceYearly:'',originalPrice:'',teacherId:''})
  const [chapters, setChapters] = useState([newChapter(1)])
  const [teachers, setTeachers] = useState([])
  const [saving, setSaving]     = useState(false)
  const [loadingCourse, setLoadingCourse] = useState(isEdit)
  const [msg, setMsg]           = useState('')

  useEffect(() => {
    loadTeachers()
    if (isEdit) loadCourse(courseId)
  }, [courseId])

  async function loadTeachers() {
    const {data:tps} = await supabase.from('teacher_profiles').select('id').eq('is_approved',true)
    const ids = (tps||[]).map(t=>t.id)
    if(!ids.length){setTeachers([]);return}
    const {data:profs} = await supabase.from('profiles').select('id,full_name').in('id',ids)
    const map = Object.fromEntries((profs||[]).map(p=>[p.id,p]))
    setTeachers((tps||[]).map(t=>({...t,profiles:map[t.id]||{}})))
  }

  async function loadCourse(id) {
    setLoadingCourse(true)
    const [{data:course},{data:lessons}] = await Promise.all([
      supabase.from('courses').select('*').eq('id',id).single(),
      supabase.from('course_lessons').select('*').eq('course_id',id).order('order_index'),
    ])
    if (!course) { setLoadingCourse(false); return }

    setForm({
      title:         course.title         || '',
      description:   course.description   || '',
      subject:       course.subject       || '',
      level:         course.level         || '',
      priceMonthly:  course.price_monthly  != null ? String(course.price_monthly)  : '',
      priceYearly:   course.price_yearly   != null ? String(course.price_yearly)   : '',
      originalPrice: course.original_price != null ? String(course.original_price) : '',
      teacherId:     course.teacher_id    || '',
    })

    // Reconstruct chapters from flat lesson rows grouped by chapter_title
    const chapterMap = {}
    const chapterOrder = []
    for (const l of (lessons||[])) {
      const ch = l.chapter_title || 'الفصل 1'
      if (!chapterMap[ch]) { chapterMap[ch] = []; chapterOrder.push(ch) }
      chapterMap[ch].push({
        id:             uid(),
        title:          l.title || '',
        type:           l.lesson_type || 'video',
        url:            l.video_url   || '',
        file:           null,
        uploadUrl:      l.video_url   || '',  // already uploaded
        isPreview:      l.is_preview  || false,
        exerciseKind:   l.quiz_data   ? 'quiz' : 'file',
        quizQuestions:  l.quiz_data   || [],
        duration:       l.duration_minutes ? String(l.duration_minutes) : '',
        pages:          l.file_pages        ? String(l.file_pages)        : '',
      })
    }
    const rebuilt = chapterOrder.map(title => ({
      id:       uid(),
      title,
      expanded: true,
      lessons:  chapterMap[title],
    }))
    setChapters(rebuilt.length > 0 ? rebuilt : [newChapter(1)])
    setLoadingCourse(false)
  }

  const set        = (k,v) => setForm(f=>({...f,[k]:v}))
  const addChapter = ()        => setChapters(c=>[...c,newChapter(c.length+1)])
  const updChapter = (i,ch)    => setChapters(c=>c.map((x,j)=>j===i?ch:x))
  const delChapter = i         => setChapters(c=>c.filter((_,j)=>j!==i))
  const addLesson  = ci        => setChapters(c=>c.map((ch,i)=>i===ci?{...ch,lessons:[...ch.lessons,newLesson()]}:ch))
  const updLesson  = (ci,li,u) => setChapters(c=>c.map((ch,i)=>i===ci?{...ch,lessons:ch.lessons.map((l,j)=>j===li?u:l)}:ch))
  const delLesson  = (ci,li)   => setChapters(c=>c.map((ch,i)=>i===ci?{...ch,lessons:ch.lessons.filter((_,j)=>j!==li)}:ch))

  async function save(isDraft) {
    if(!form.title||!form.subject||!form.level||!form.priceMonthly||!form.teacherId){
      setMsg('يرجى تعبئة جميع الحقول المطلوبة (العنوان، المادة، المستوى، السعر الشهري، الأستاذ)')
      return
    }
    setSaving(true); setMsg('')
    try {
      // Upload only NEW files (file !== null)
      const uploaded = await Promise.all(chapters.map(async ch=>({
        ...ch,
        lessons: await Promise.all(ch.lessons.map(async l=>{
          if(!l.file) return l
          const bucket = l.type==='video' ? 'course-videos' : 'course-files'
          return {...l, uploadUrl: await uploadFile(bucket, l.file)}
        }))
      })))

      const total      = uploaded.reduce((s,ch)=>s+ch.lessons.length,0)
      const totalMins  = uploaded.reduce((s,ch)=>s+ch.lessons.reduce((ss,l)=>ss+(parseInt(l.duration)||0),0),0)
      const totalHours = parseFloat((totalMins/60).toFixed(1))

      const courseData = {
        title:         form.title,
        description:   form.description,
        subject:       form.subject,
        level:         form.level,
        price_monthly: parseFloat(form.priceMonthly),
        price_yearly:  form.priceYearly   ? parseFloat(form.priceYearly)   : null,
        original_price:form.originalPrice ? parseFloat(form.originalPrice) : null,
        teacher_id:    form.teacherId,
        is_active:     !isDraft,
        total_lessons: total,
        total_hours:   totalHours,
      }

      let finalCourseId = courseId
      if (isEdit) {
        const {error} = await supabase.from('courses').update(courseData).eq('id', courseId)
        if (error) throw error
        // Replace all lessons atomically
        await supabase.from('course_lessons').delete().eq('course_id', courseId)
      } else {
        const {data:course,error} = await supabase.from('courses').insert(courseData).select().single()
        if (error) throw error
        finalCourseId = course.id
      }

      const lessonRows = []
      let order = 0
      for(const ch of uploaded)
        for(const l of ch.lessons){
          order++
          lessonRows.push({
            course_id:        finalCourseId,
            title:            l.title || ('درس '+order),
            video_url:        l.uploadUrl || l.url || null,
            order_index:      order,
            is_preview:       l.isPreview,
            lesson_type:      l.type,
            chapter_title:    ch.title,
            duration_minutes: parseInt(l.duration)||0,
            file_pages:       parseInt(l.pages)||0,
            quiz_data:        (l.type==='exercise'&&l.exerciseKind==='quiz'&&l.quizQuestions?.length>0)?l.quizQuestions:null,
          })
        }
      if(lessonRows.length>0){
        const{error:le}=await supabase.from('course_lessons').insert(lessonRows)
        if(le) throw le
      }
      onNavigate('courses')
    } catch(err){
      setMsg('خطأ: '+(err.message||String(err)))
    }
    setSaving(false)
  }

  if (loadingCourse) return <div className="loading-center"><div className="spinner" /></div>

  const totalLessons = chapters.reduce((s,ch)=>s+ch.lessons.length,0)

  return (
    <div>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:20}}>
        <button className="btn btn-secondary btn-sm" onClick={()=>onNavigate('courses')}>← الرجوع</button>
        <div style={{display:'flex',gap:10}}>
          <button className="btn btn-secondary" disabled={saving} onClick={()=>save(true)}>💾 مسودّة</button>
          <button className="btn btn-primary" style={{background:'#1B9E77'}} disabled={saving} onClick={()=>save(false)}>
            {saving
              ? <span className="spinner" style={{width:17,height:17,borderWidth:2}}/>
              : isEdit ? '💾 حفظ التعديلات' : '🚀 نشر الدرس'}
          </button>
        </div>
      </div>
      {msg && <div className="login-error" style={{marginBottom:16}}>{msg}</div>}

      {isEdit && (
        <div className="info-banner blue" style={{marginBottom:16}}>
          ✏️ &nbsp;وضع التعديل — أي تغيير في الدروس سيحل محل الدروس الحالية كاملاً عند الحفظ.
        </div>
      )}

      <div style={{display:'grid',gridTemplateColumns:'1.65fr 1fr',gap:20,maxWidth:1180}}>
        {/* LEFT */}
        <div style={{display:'flex',flexDirection:'column',gap:18}}>
          <div className="card">
            <div className="card-title" style={{marginBottom:14}}>معلومات الدرس *</div>
            <div className="field-label">عنوان الدرس</div>
            <input className="field-input" style={{marginBottom:14}} placeholder="مثال: إتقان الرياضيات — باكالوريا" value={form.title} onChange={e=>set('title',e.target.value)} />
            <div className="field-label">وصف قصير</div>
            <textarea className="field-input" placeholder="دورة شاملة تغطي…" rows={3} value={form.description} onChange={e=>set('description',e.target.value)} style={{resize:'vertical'}} />
          </div>

          <div className="card">
            <div className="field-label" style={{marginBottom:10}}>المادة الدراسية *</div>
            <div style={{display:'flex',flexWrap:'wrap',gap:8}}>
              {SUBJECTS.map(s=><span key={s} className={'chip'+(form.subject===s?' active':'')} onClick={()=>set('subject',s)}>{s}</span>)}
            </div>
          </div>

          <div className="card">
            <div className="field-label" style={{marginBottom:12}}>المستوى الدراسي *</div>
            {LEVELS.map(g=>(
              <div key={g.group} style={{marginBottom:14}}>
                <div style={{fontSize:11,fontWeight:700,color:'var(--text3)',marginBottom:7}}>{g.group}</div>
                <div style={{display:'flex',flexWrap:'wrap',gap:7}}>
                  {g.items.map(l=><span key={l} className={'chip'+(form.level===l?' active':'')} style={{fontSize:11.5,padding:'6px 11px'}} onClick={()=>set('level',l)}>{l}</span>)}
                </div>
              </div>
            ))}
          </div>

          {/* Chapters */}
          <div>
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',padding:'14px 18px',background:'#0E2B33',borderRadius:14,marginBottom:16}}>
              <div>
                <div style={{fontSize:15,fontWeight:800,color:'#fff'}}>الفصول والدروس</div>
                <div style={{fontSize:12,color:'#7ABBC4',marginTop:2}}>{chapters.length} فصل · {totalLessons} درس إجمالاً</div>
              </div>
              <button onClick={addChapter} style={{display:'flex',alignItems:'center',gap:8,padding:'10px 20px',background:'#1B9E77',color:'#fff',border:'none',borderRadius:11,fontSize:14,fontWeight:700,cursor:'pointer',fontFamily:'inherit',boxShadow:'0 3px 10px rgba(27,158,119,.35)'}}>
                ＋ إضافة فصل جديد
              </button>
            </div>
            <div style={{display:'flex',flexDirection:'column',gap:16}}>
              {chapters.length===0
                ? <div onClick={addChapter} style={{border:'2.5px dashed #BDD1D9',borderRadius:16,padding:'40px 20px',textAlign:'center',cursor:'pointer',background:'#F7FAFB'}}>
                    <div style={{fontSize:48,marginBottom:12}}>📚</div>
                    <div style={{fontSize:15,fontWeight:700,color:'#3A5260',marginBottom:6}}>ابدأ بإضافة أول فصل</div>
                    <div style={{fontSize:12.5,color:'#8A9EAB'}}>كل فصل يحتوي على دروس: فيديو · ملف · تمرين · ملخّص</div>
                    <div style={{marginTop:16,display:'inline-flex',alignItems:'center',gap:7,padding:'9px 20px',borderRadius:10,background:'#1B6B7A',color:'#fff',fontSize:13,fontWeight:700}}>＋ إضافة فصل</div>
                  </div>
                : chapters.map((ch,i)=><ChapterBlock key={ch.id} chapter={ch} idx={i} onUpdate={updChapter} onDelete={delChapter} onLessonUpdate={updLesson} onLessonDelete={delLesson} onAddLesson={addLesson} />)
              }
            </div>
          </div>
        </div>

        {/* RIGHT */}
        <div style={{display:'flex',flexDirection:'column',gap:18}}>
          <div className="card">
            <div className="card-title" style={{marginBottom:16}}>الأسعار</div>
            <div className="field-label" style={{marginBottom:6}}>السعر الشهري <span style={{color:'#E53E3E'}}>*</span></div>
            <div style={{display:'flex',alignItems:'center',border:'1.5px solid #E1E5E9',borderRadius:10,overflow:'hidden',background:'#FCFCFD',marginBottom:12}}>
              <input type="number" style={{border:'none',background:'transparent',fontSize:17,fontWeight:700,padding:'11px 13px',width:'100%',outline:'none',fontFamily:'inherit'}} placeholder="1200" value={form.priceMonthly} onChange={e=>set('priceMonthly',e.target.value)} />
              <span style={{padding:'0 13px',fontSize:12,color:'var(--text3)',fontWeight:600,whiteSpace:'nowrap',borderRight:'1px solid #E1E5E9'}}>أوقية/شهر</span>
            </div>
            <div className="field-label" style={{marginBottom:6}}>السعر السنوي <span style={{fontSize:10.5,color:'var(--text3)',fontWeight:400}}>(اختياري)</span></div>
            <div style={{display:'flex',alignItems:'center',border:'1.5px solid #E1E5E9',borderRadius:10,overflow:'hidden',background:'#FCFCFD',marginBottom:12}}>
              <input type="number" style={{border:'none',background:'transparent',fontSize:17,fontWeight:700,padding:'11px 13px',width:'100%',outline:'none',fontFamily:'inherit'}} placeholder="11000" value={form.priceYearly} onChange={e=>set('priceYearly',e.target.value)} />
              <span style={{padding:'0 13px',fontSize:12,color:'var(--text3)',fontWeight:600,whiteSpace:'nowrap',borderRight:'1px solid #E1E5E9'}}>أوقية/سنة</span>
            </div>
            <div className="field-label" style={{marginBottom:6}}>السعر الأصلي قبل الخصم <span style={{fontSize:10.5,color:'var(--text3)',fontWeight:400}}>(اختياري)</span></div>
            <div style={{display:'flex',alignItems:'center',border:'1.5px solid #E1E5E9',borderRadius:10,overflow:'hidden',background:'#FCFCFD'}}>
              <input type="number" style={{border:'none',background:'transparent',fontSize:17,fontWeight:700,padding:'11px 13px',width:'100%',outline:'none',fontFamily:'inherit'}} placeholder="1600" value={form.originalPrice} onChange={e=>set('originalPrice',e.target.value)} />
              <span style={{padding:'0 13px',fontSize:12,color:'var(--text3)',fontWeight:600,whiteSpace:'nowrap',borderRight:'1px solid #E1E5E9'}}>أوقية</span>
            </div>
            {(form.priceMonthly||form.priceYearly||form.originalPrice) && (
              <div style={{marginTop:13,padding:'11px 13px',background:'#F7F9FA',borderRadius:10,border:'1px solid #EFF2F4'}}>
                <div style={{fontSize:10.5,color:'var(--text3)',fontWeight:700,marginBottom:7}}>معاينة عرض السعر</div>
                <div style={{display:'flex',alignItems:'baseline',gap:8,flexWrap:'wrap'}}>
                  {form.originalPrice&&<span style={{fontSize:13,color:'#B0BEC5',textDecoration:'line-through'}}>{form.originalPrice} أوقية</span>}
                  {form.priceMonthly&&<span style={{fontSize:20,fontWeight:700,color:'var(--primary)'}}>{form.priceMonthly} أوقية<span style={{fontSize:11,fontWeight:400}}>/شهر</span></span>}
                  {form.priceYearly&&<span style={{fontSize:13,color:'#1B9E77',fontWeight:700}}> · {form.priceYearly} أوقية/سنة</span>}
                </div>
                {form.originalPrice&&form.priceMonthly&&(
                  <div style={{marginTop:5,fontSize:11,fontWeight:700,color:'#1B9E77'}}>
                    🏷 خصم {Math.round((1-parseFloat(form.priceMonthly)/parseFloat(form.originalPrice))*100)}%
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="card">
            <div className="card-title" style={{marginBottom:14}}>الأستاذ *</div>
            {teachers.length===0
              ? <div style={{color:'var(--text3)',fontSize:13,textAlign:'center',padding:'12px 0'}}>لا يوجد أساتذة معتمدون</div>
              : <div style={{display:'flex',flexDirection:'column',gap:8,maxHeight:280,overflowY:'auto'}}>
                  {teachers.map(t=>{
                    const name=t.profiles?.full_name||'—'; const sel=form.teacherId===t.id
                    return <div key={t.id} onClick={()=>set('teacherId',t.id)} style={{display:'flex',alignItems:'center',gap:11,padding:'10px 13px',border:'1.5px solid '+(sel?'var(--primary)':'#EFF2F4'),borderRadius:11,cursor:'pointer',background:sel?'var(--primary-light)':'transparent',transition:'.1s'}}>
                      <span style={{width:34,height:34,borderRadius:10,background:'#E7F1F2',color:'var(--primary)',display:'flex',alignItems:'center',justifyContent:'center',fontWeight:700,flexShrink:0}}>{name[0]}</span>
                      <span style={{fontWeight:600,fontSize:13,flex:1,color:sel?'var(--primary)':'var(--text)'}}>{name}</span>
                      {sel&&<span style={{color:'var(--primary)'}}>✓</span>}
                    </div>
                  })}
                </div>
            }
          </div>

          <div style={{background:'#0E2B33',borderRadius:14,padding:'18px 20px',color:'#fff'}}>
            <div style={{fontSize:12.5,fontWeight:700,marginBottom:14,color:'#7ABBC4'}}>ملخّص الدرس</div>
            {[
              ['📚','الفصول',chapters.length],
              ['🎬','إجمالي الدروس',totalLessons],
              ['✅','مجانية',chapters.reduce((s,c)=>s+c.lessons.filter(l=>l.isPreview).length,0)],
              ['🎬','فيديوهات',chapters.reduce((s,c)=>s+c.lessons.filter(l=>l.type==='video').length,0)],
              ['📝','تمارين',chapters.reduce((s,c)=>s+c.lessons.filter(l=>l.type==='exercise').length,0)],
              ['📋','ملخّصات',chapters.reduce((s,c)=>s+c.lessons.filter(l=>l.type==='summary').length,0)],
            ].map(([icon,label,val])=>(
              <div key={label} style={{display:'flex',justifyContent:'space-between',fontSize:12.5,marginBottom:9}}>
                <span style={{color:'#8AACB3'}}>{icon} {label}</span>
                <span style={{fontWeight:700,color:'#7BE0C0'}}>{val}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
