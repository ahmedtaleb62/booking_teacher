import React, { useState, useEffect, useRef } from 'react'
import { supabase } from '../supabase'

const LEVELS = [
  { group: 'ابتدائية', items: ['سنة أولى ابتدائي','سنة ثانية ابتدائي','سنة ثالثة ابتدائي','سنة رابعة ابتدائي','سنة خامسة ابتدائي','سنة سادسة (Concours)'] },
  { group: 'إعدادية',  items: ['سنة أولى إعدادي','سنة ثانية إعدادي','سنة ثالثة إعدادي','سنة رابعة (Brevet)'] },
  { group: 'ثانوية',   items: ['سنة خامسة ثانوي','سنة سادسة ثانوي','BAC C','BAC D','BAC LO','BAC LA','BAC TGM'] },
]
const SUBJECTS = ['العربية','الفرنسية','الإنجليزية','الرياضيات','الفيزياء والكيمياء','التاريخ والجغرافيا','الفلسفة','العلوم الطبيعية','التربية الإسلامية','التربية المدنية']
const uid        = () => Math.random().toString(36).slice(2)
const newLesson  = () => ({
  id: uid(), title: '', url: '', file: null, uploadUrl: '',
  isPreview: false, duration: '', pages: '',
  attachmentFile: null, attachmentUrl: '',
  quizQuestions: [],
})
const newChapter = n  => ({ id:uid(), title:'الفصل '+n, expanded:true, lessons:[newLesson()] })
const newQuestion= () => ({ id:uid(), text:'', answers:['',''], correct:0 })

const MAX_UPLOAD_BYTES = 2 * 1024 * 1024 * 1024 // 2GB sanity cap — R2 itself has no meaningful limit here

// Videos/files upload directly to Cloudflare R2 (no size cap like Supabase's
// free-tier 50MB storage limit). The admin's Pages Function signs a short-
// lived R2 PUT URL after verifying the caller is an admin; the actual bytes
// go straight from the browser to R2, never through our own server.
async function uploadFile(bucket, file) {
  if (file.size > MAX_UPLOAD_BYTES) {
    const sizeMB = (file.size / (1024*1024)).toFixed(1)
    throw new Error(`حجم الملف ${sizeMB} ميجابايت كبير جداً (الحد الأقصى 2 غيغابايت)`)
  }
  const kind = bucket === 'course-videos' ? 'video' : 'file'

  const { data: { session } } = await supabase.auth.getSession()
  if (!session) throw new Error('انتهت الجلسة، سجّل الدخول من جديد')

  const presignRes = await fetch('/api/presign-upload', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${session.access_token}`,
    },
    body: JSON.stringify({ filename: file.name, kind }),
  })
  if (!presignRes.ok) throw new Error('تعذّر تجهيز رابط الرفع، حاول مرة أخرى')
  const { uploadUrl, publicUrl } = await presignRes.json()

  const putRes = await fetch(uploadUrl, { method: 'PUT', body: file })
  if (!putRes.ok) throw new Error('فشل رفع الملف، تحقق من اتصالك وحاول مرة أخرى')

  return publicUrl
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
function SectionToggle({ icon, label, color, active, onToggle }) {
  return (
    <button onClick={onToggle} style={{display:'flex',alignItems:'center',gap:6,padding:'6px 13px',borderRadius:20,border:'1.5px solid '+(active?color:'#D6DFE6'),background:active?color+'18':'#F8FAFB',color:active?color:'#8A96A3',fontSize:12,fontWeight:700,cursor:'pointer',fontFamily:'inherit',transition:'all .15s'}}>
      {icon} {label} {active ? '✓' : '+'}
    </button>
  )
}

function LessonItem({ lesson, ci, li, onUpdate, onDelete }) {
  const [collapsed, setCollapsed] = useState(false)
  const [confirmDel, setConfirmDel] = useState(false)
  const set = f => onUpdate(ci, li, {...lesson,...f})

  const hasAttachment = !!(lesson.attachmentFile || lesson.attachmentUrl)
  const hasQuiz       = lesson.quizQuestions?.length > 0

  return (
    <div style={{borderRadius:12,overflow:'hidden',background:'#fff',border:'1.5px solid #E4EBF0',boxShadow:'0 1px 4px rgba(0,0,0,.04)'}}>
      {/* ─ Header ─ */}
      <div style={{display:'flex',alignItems:'center',gap:8,padding:'10px 12px',background:'#F8FAFB',borderBottom:collapsed?'none':'1.5px solid #EDF1F4',flexWrap:'wrap'}}>
        <input
          className="field-input"
          value={lesson.title}
          placeholder="عنوان الدرس…"
          onChange={e=>set({title:e.target.value})}
          style={{flex:'1 1 200px',fontSize:13,fontWeight:600,padding:'6px 10px',minWidth:0}}
        />
        {/* Duration (minutes) — shown when video present or no file */}
        {(!hasAttachment || lesson.url || lesson.file || lesson.uploadUrl) && (
          <div style={{display:'flex',alignItems:'center',gap:4,flexShrink:0}}>
            <input type="number" min="0" placeholder="0" value={lesson.duration||''} onChange={e=>set({duration:e.target.value})}
              style={{width:50,padding:'6px 7px',borderRadius:8,border:'1.5px solid #D6DFE6',fontSize:12,fontWeight:700,textAlign:'center',fontFamily:'inherit'}} />
            <span style={{fontSize:11,color:'#8A96A3'}}>د</span>
          </div>
        )}
        {/* Pages — shown when file attachment present */}
        {hasAttachment && (
          <div style={{display:'flex',alignItems:'center',gap:4,flexShrink:0}}>
            <input type="number" min="0" placeholder="0" value={lesson.pages||''} onChange={e=>set({pages:e.target.value})}
              style={{width:50,padding:'6px 7px',borderRadius:8,border:'1.5px solid #C3D4F5',fontSize:12,fontWeight:700,textAlign:'center',fontFamily:'inherit',color:'#2A5EBF'}} />
            <span style={{fontSize:11,color:'#2A5EBF'}}>ص</span>
          </div>
        )}
        <label style={{display:'flex',alignItems:'center',gap:5,cursor:'pointer',userSelect:'none',padding:'5px 10px',borderRadius:20,border:'1.5px solid '+(lesson.isPreview?'#1B9E77':'#DDE3E8'),background:lesson.isPreview?'#E3F6EF':'#fff',color:lesson.isPreview?'#15805F':'#8A96A3',fontSize:11.5,fontWeight:700,flexShrink:0}}>
          <input type="checkbox" checked={lesson.isPreview} onChange={e=>set({isPreview:e.target.checked})} style={{display:'none'}} />
          {lesson.isPreview?'✓ مجاني':'مجاني'}
        </label>
        <button onClick={()=>setCollapsed(c=>!c)} title={collapsed?'عرض':'طي'} style={{width:30,height:30,borderRadius:8,border:'1.5px solid #D6DFE6',background:'#fff',color:'#8A96A3',fontSize:13,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,transition:'transform .15s',transform:collapsed?'rotate(180deg)':'none'}}>▲</button>
        {confirmDel
          ? <div style={{display:'flex',gap:5,flexShrink:0}}>
              <button onClick={()=>onDelete(ci,li)} style={{padding:'5px 11px',borderRadius:8,border:'none',background:'#A12B1D',color:'#fff',fontSize:12,fontWeight:700,cursor:'pointer',fontFamily:'inherit'}}>تأكيد</button>
              <button onClick={()=>setConfirmDel(false)} style={{padding:'5px 11px',borderRadius:8,border:'1.5px solid #DDE3E8',background:'#fff',color:'#516170',fontSize:12,fontWeight:700,cursor:'pointer',fontFamily:'inherit'}}>إلغاء</button>
            </div>
          : <button onClick={()=>setConfirmDel(true)} style={{padding:'5px 10px',borderRadius:8,border:'1.5px solid #F3C5BD',background:'#FBE0DB',color:'#A12B1D',fontSize:12,fontWeight:700,cursor:'pointer',fontFamily:'inherit',flexShrink:0}}>🗑</button>
        }
      </div>

      {/* ─ Body ─ */}
      {!collapsed && (
        <div style={{padding:'14px 14px 16px',display:'flex',flexDirection:'column',gap:14}}>

          {/* ── 1. فيديو ── */}
          <div style={{border:'1.5px solid #D0EAE4',borderRadius:10,overflow:'hidden'}}>
            <div style={{background:'#E8F5F2',padding:'8px 12px',fontSize:12.5,fontWeight:700,color:'#0E7C66'}}>🎬 فيديو</div>
            <div style={{padding:'12px',display:'flex',flexDirection:'column',gap:10}}>
              <div>
                <div className="field-label" style={{marginBottom:6}}>🔗 رابط الفيديو (YouTube / Vimeo / مباشر)</div>
                <input className="field-input" dir="ltr" placeholder="https://youtube.com/watch?v=..." value={lesson.url} onChange={e=>set({url:e.target.value,uploadUrl:''})} style={{fontSize:12.5}} />
              </div>
              <div style={{textAlign:'center',fontSize:12,color:'#A0B4BE',fontWeight:700}}>— أو رفع ملف فيديو مباشرة —</div>
              <DropZone accept="video/*" icon="🎬" hint="MP4، MOV — حتى 50 MB (الأكبر: ارفعه على يوتيوب وألصق الرابط أعلاه)" file={lesson.file} existingUrl={lesson.uploadUrl&&!lesson.url?lesson.uploadUrl:null} onChange={f=>set({file:f,url:'',uploadUrl:''})} />
            </div>
          </div>

          {/* ── 2. ملف مرفق ── */}
          <div style={{border:'1.5px solid '+(hasAttachment?'#C3D4F5':'#E0E8F0'),borderRadius:10,overflow:'hidden'}}>
            <div style={{background:hasAttachment?'#EBF1FD':'#F4F7FB',padding:'8px 12px',display:'flex',alignItems:'center',justifyContent:'space-between'}}>
              <span style={{fontSize:12.5,fontWeight:700,color:hasAttachment?'#2A5EBF':'#6B7E8E'}}>📎 ملف مرفق (PDF / مستند)</span>
              {hasAttachment && (
                <button onClick={()=>set({attachmentFile:null,attachmentUrl:''})} style={{background:'none',border:'none',cursor:'pointer',color:'#C0C9D2',fontSize:14}}>✕ حذف</button>
              )}
            </div>
            <div style={{padding:'12px'}}>
              <DropZone
                accept=".pdf,.doc,.docx,.ppt,.pptx,.xls,.xlsx"
                icon="📄"
                hint="PDF، Word، PowerPoint — حتى 50 MB"
                file={lesson.attachmentFile}
                existingUrl={lesson.attachmentUrl || null}
                onChange={f=>set({attachmentFile:f, attachmentUrl: f ? '' : lesson.attachmentUrl})}
              />
            </div>
          </div>

          {/* ── 3. اختبار ── */}
          <div style={{border:'1.5px solid '+(hasQuiz?'#D4BAF5':'#E0E8F0'),borderRadius:10,overflow:'hidden'}}>
            <div style={{background:hasQuiz?'#F3EDFB':'#F4F7FB',padding:'8px 12px',display:'flex',alignItems:'center',justifyContent:'space-between'}}>
              <span style={{fontSize:12.5,fontWeight:700,color:hasQuiz?'#6B32C0':'#6B7E8E'}}>📝 QCM</span>
              {hasQuiz && (
                <button onClick={()=>set({quizQuestions:[]})} style={{background:'none',border:'none',cursor:'pointer',color:'#C0C9D2',fontSize:14}}>✕ حذف QCM</button>
              )}
            </div>
            <div style={{padding:'12px'}}>
              <QuizBuilder
                questions={lesson.quizQuestions || []}
                onChange={qs=>set({quizQuestions:qs})}
              />
            </div>
          </div>

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
                <button onClick={()=>onDelete(idx)} style={{padding:'7px 14px',borderRadius:9,border:'none',background:'#A12B1D',color:'#fff',fontSize:12.5,fontWeight:700,cursor:'pointer',fontFamily:'inherit',whiteSpace:'nowrap'}}>✓ تأكيد الحذف</button>
                <button onClick={()=>setConfirmDel(false)} style={{padding:'7px 14px',borderRadius:9,border:'1.5px solid rgba(255,255,255,.35)',background:'rgba(255,255,255,.1)',color:'#fff',fontSize:12.5,fontWeight:700,cursor:'pointer',fontFamily:'inherit'}}>إلغاء</button>
              </div>
            : <button onClick={()=>setConfirmDel(true)} style={{display:'flex',alignItems:'center',gap:5,padding:'7px 13px',borderRadius:9,border:'1.5px solid #F3C5BD',background:'rgba(161,43,29,.18)',color:'#F3C5BD',fontSize:12.5,fontWeight:700,cursor:'pointer',fontFamily:'inherit',whiteSpace:'nowrap'}}>🗑 حذف الفصل</button>
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
  const [isFree, setIsFree]     = useState(false)
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
      supabase.from('course_lessons').select('id,title,video_url,file_url,file_pages,order_index,duration_minutes,is_preview,lesson_type,chapter_title,quiz_data').eq('course_id',id).order('order_index'),
    ])
    if (!course) { setLoadingCourse(false); return }

    const free = course.price_monthly === 0
    setIsFree(free)
    setForm({
      title:         course.title         || '',
      description:   course.description   || '',
      subject:       course.subject       || '',
      level:         course.level         || '',
      priceMonthly:  !free && course.price_monthly  != null ? String(course.price_monthly)  : '',
      priceYearly:   !free && course.price_yearly   != null ? String(course.price_yearly)   : '',
      originalPrice: !free && course.original_price != null ? String(course.original_price) : '',
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
        url:            l.video_url   || '',
        file:           null,
        uploadUrl:      l.video_url   || '',
        isPreview:      l.is_preview  || false,
        duration:       l.duration_minutes ? String(l.duration_minutes) : '',
        pages:          l.file_pages ? String(l.file_pages) : '',
        attachmentFile: null,
        attachmentUrl:  l.file_url    || '',
        quizQuestions:  l.quiz_data   || [],
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
    if(!form.title||!form.subject||!form.level||(!isFree&&!form.priceMonthly)||!form.teacherId){
      setMsg('يرجى تعبئة جميع الحقول المطلوبة (العنوان، المادة، المستوى، السعر أو مجاني، الأستاذ)')
      return
    }
    // Catch a common mistake: pasting a document link into the "video URL"
    // field instead of using the file-attachment uploader below it.
    const DOC_EXT = /\.(pdf|docx?|pptx?|xlsx?)(\?|$)/i
    for (const ch of chapters)
      for (const l of ch.lessons)
        if (l.url && DOC_EXT.test(l.url)) {
          setMsg(`رابط الفيديو في الدرس "${l.title||'بدون عنوان'}" يبدو أنه رابط ملف (PDF/Word/…) وليس فيديو — انقله لخانة "ملف مرفق" بدلاً من "رابط الفيديو"`)
          return
        }
    setSaving(true); setMsg('')
    try {
      // Upload only NEW files
      const uploaded = await Promise.all(chapters.map(async ch=>({
        ...ch,
        lessons: await Promise.all(ch.lessons.map(async l=>{
          let uploadUrl       = l.uploadUrl
          let attachmentUrl   = l.attachmentUrl
          if (l.file)           uploadUrl     = await uploadFile('course-videos', l.file)
          if (l.attachmentFile) attachmentUrl = await uploadFile('course-files',  l.attachmentFile)
          return {...l, uploadUrl, attachmentUrl}
        }))
      })))

      // Compute totals first (before saving course)
      let totalMins = 0
      for (const ch of uploaded)
        for (const l of ch.lessons)
          totalMins += parseInt(l.duration)||0

      // Count actual DB rows that will be created (each content type = 1 row)
      let totalRows = 0
      for (const ch of uploaded)
        for (const l of ch.lessons) {
          const hasVideo = !!(l.uploadUrl || l.url)
          const hasFile  = !!l.attachmentUrl
          const hasQuiz  = !!(l.quizQuestions?.length > 0)
          if (!hasVideo && !hasFile && !hasQuiz) totalRows++
          else { if (hasVideo) totalRows++; if (hasFile) totalRows++; if (hasQuiz) totalRows++ }
        }

      const totalHours = parseFloat((totalMins/60).toFixed(1))

      const courseData = {
        title:         form.title,
        description:   form.description,
        subject:       form.subject,
        level:         form.level,
        price_monthly: isFree ? 0 : parseFloat(form.priceMonthly),
        price_yearly:  isFree ? null : (form.priceYearly   ? parseFloat(form.priceYearly)   : null),
        original_price:isFree ? null : (form.originalPrice ? parseFloat(form.originalPrice) : null),
        teacher_id:    form.teacherId,
        is_active:     !isDraft,
        total_lessons: totalRows,
        total_hours:   totalHours,
      }

      let finalCourseId = courseId
      if (isEdit) {
        const {error} = await supabase.from('courses').update(courseData).eq('id', courseId)
        if (error) throw error
        const {error: delErr} = await supabase.from('course_lessons').delete().eq('course_id', courseId)
        if (delErr) throw delErr
      } else {
        const {data:course,error} = await supabase.from('courses').insert(courseData).select().single()
        if (error) throw error
        finalCourseId = course.id
      }

      // Build lesson rows: each content type becomes a separate DB row
      const lessonRows = []
      let order = 0
      for (const ch of uploaded) {
        for (const l of ch.lessons) {
          const hasVideo = !!(l.uploadUrl || l.url)
          const hasFile  = !!l.attachmentUrl
          const hasQuiz  = !!(l.quizQuestions?.length > 0)

          if (!hasVideo && !hasFile && !hasQuiz) {
            order++
            lessonRows.push({
              course_id: finalCourseId, title: l.title || ('درس '+order),
              video_url: null, file_url: null, order_index: order,
              is_preview: l.isPreview, lesson_type: 'video',
              chapter_title: ch.title, duration_minutes: parseInt(l.duration)||0,
              file_pages: 0, quiz_data: null,
            })
            continue
          }

          if (hasVideo) {
            order++
            lessonRows.push({
              course_id: finalCourseId,
              title: l.title || ('درس '+order),
              video_url: l.uploadUrl || l.url, file_url: null, order_index: order,
              is_preview: l.isPreview, lesson_type: 'video',
              chapter_title: ch.title, duration_minutes: parseInt(l.duration)||0,
              file_pages: 0, quiz_data: null,
            })
          }

          if (hasFile) {
            order++
            // Store file URL in video_url so Flutter can display it via WebView
            lessonRows.push({
              course_id: finalCourseId,
              title: 'ملف ' + order,
              video_url: l.attachmentUrl, file_url: l.attachmentUrl, order_index: order,
              is_preview: l.isPreview, lesson_type: 'file',
              chapter_title: ch.title, duration_minutes: 0,
              file_pages: parseInt(l.pages)||0, quiz_data: null,
            })
          }

          if (hasQuiz) {
            order++
            lessonRows.push({
              course_id: finalCourseId,
              title: 'QCM ' + order,
              video_url: null, file_url: null, order_index: order,
              is_preview: l.isPreview, lesson_type: 'exercise',
              chapter_title: ch.title, duration_minutes: 0,
              file_pages: 0, quiz_data: l.quizQuestions,
            })
          }
        }
      }

      if (lessonRows.length > 0) {
        const {error:le} = await supabase.from('course_lessons').insert(lessonRows)
        if (le) throw le
      }
      if (!isDraft && !isEdit) {
        try {
          await supabase.rpc('send_admin_notification', {
            p_target_type: 'students',
            p_title: 'درس جديد متاح 📖',
            p_body:  form.title,
            p_type:  'NEW_COURSE',
          })
        } catch (_) {}
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
            <div className="card-title" style={{marginBottom:14}}>التسعير</div>

            {/* Free toggle */}
            <div
              onClick={() => { setIsFree(v => !v); set('priceMonthly',''); set('priceYearly',''); set('originalPrice','') }}
              style={{display:'flex',alignItems:'center',gap:12,padding:'13px 15px',borderRadius:11,border:'2px solid '+(isFree?'#1B9E77':'#E1E5E9'),background:isFree?'#F0FBF7':'#FAFBFC',cursor:'pointer',marginBottom:14,transition:'all .15s'}}
            >
              <div style={{width:42,height:24,borderRadius:12,background:isFree?'#1B9E77':'#C9D3DC',position:'relative',transition:'background .2s',flexShrink:0}}>
                <div style={{position:'absolute',top:3,right:isFree?3:undefined,left:isFree?undefined:3,width:18,height:18,borderRadius:'50%',background:'#fff',transition:'all .2s',boxShadow:'0 1px 3px rgba(0,0,0,.2)'}} />
              </div>
              <div>
                <div style={{fontSize:13,fontWeight:700,color:isFree?'#15805F':'var(--text)'}}>مجاني بالكامل 🎁</div>
                <div style={{fontSize:11,color:'var(--text3)',marginTop:2}}>الطلاب يشاهدون الدروس دون اشتراك</div>
              </div>
            </div>

            {!isFree && (<>
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
            </>)}
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
