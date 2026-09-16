"""Exact deterministic copy for each shared Home card presentation."""
TASKS=['Sketch the first draft','Book a library visit','Water the balcony plants','Review the weekly plan','Send the project notes','Pack a walking bag','Choose tomorrow’s focus']
ROUTINES=['Morning stretch','Read for ten minutes','Water the plants','Prepare a walking bag','Evening wind-down']
ROUTES={'goals':'View goals','routines':'View routines','lifeMoment':'View moments','logMeal':'Log meal','nutritionSummary':'View nutrition','bodyMetric':'View body metrics','workout':'View workouts','sleep':'View sleep','movement':'View movement','fasting':'View fasting'}
def content(kind,title,preset,value,detail,action):
 result={'title':title,'value':value,'detail':detail,'rows':[],'actions':[ROUTES.get(kind,action)]}
 if preset=='compact': return {'title':title,'value':value,'detail':'','rows':[],'actions':[], 'whole_card_action':'Opens the source'}
 if kind=='journal': return dict(title='Journal',value='',detail='Keep one honest moment from today—words, photos, or audio.',rows=[],actions=['Write','Search','Weekly reflection'])
 if kind=='scheduleCapacity': return dict(title='Capacity',value='1h 30m known room',detail='Usable capacity 4h',rows=[],actions=['Open Day'])
 if kind=='tasks': return dict(title='Today’s tasks',value='',detail='',rows=TASKS[:6 if preset=='expanded' else 4],actions=['Add a task','Show more'],row_controls='Native completion circle and task-detail chevron for every row; all tasks open')
 if kind in ('care','routines'):
  limit=5 if preset=='expanded' else 4 if preset=='tall' else 3
  return dict(title='Morning care' if kind=='care' else 'Morning routines',value='',detail='',rows=['Medication decision — Scheduled']*limit if kind=='care' else ROUTINES[:limit],actions=['Open Care' if kind=='care' else 'View morning routines'])
 if kind=='progressReflection': return dict(title='Progress',value='',detail='',rows=['7 open','2 of 14 days · 1 day running'],actions=['See evidence behind today'],native_graphic='Linear progress indicator at 40%; no printed percentage or invented chart')
 if kind=='focusNow' and preset!='standard': return dict(title='Focus Now',value=value,detail=detail,rows=[],actions=['Start'])
 if kind=='lifeSnapshot' and preset!='standard': return dict(title='How life feels',value='',detail='',rows=['Check in — Mood','500 ml — Hydration','Connect — Steps','Connect — Active'],actions=[],row_controls='Each signal is a native 44-point-minimum button; adaptive grid')
 if kind=='fasting' and preset!='standard': return dict(title='Active fast',value='',detail='No fast is active',rows=[],actions=['Start a fast'])
 if kind=='quickCapture' and preset=='wide': return dict(title='Capture',value='',detail='',rows=[],actions=['Task','Habit','Journal','Water'],control_layout='Four native capture tiles; care feature explicitly enabled')
 if kind=='compactTimeline' and preset!='standard': return dict(title='Now & next',value='',detail='',rows=['9:00 AM — Design review','2:00 PM — Afternoon walk'],actions=['Open complete day shape'])
 if kind in ('goals','setupChecklist'): result['native_graphic']='Native progress ring at 60% labeled 3 of 5' if kind=='goals' else 'Native progress ring at 40% labeled 2 of 5'
 return result
