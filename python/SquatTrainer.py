import cv2, mediapipe as mp
import numpy as np
import time
import PoseModule as pm


detector= pm.PoseDetector()
cap = cv2.VideoCapture(0)
# ask the camera for a bigger picture (720p)
cap.set(cv2.CAP_PROP_FRAME_WIDTH,1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT,720)
# a window you can resize / make full screen
cv2.namedWindow("image",cv2.WINDOW_NORMAL)
cv2.resizeWindow("image",1280,720)

ptime=0
ctime=0
count=0
dir=0
smooth_angle=None
last_rep_time=0
while True:
    success, img=cap.read()
    if not success:
        continue
    img=detector.findPose(img)
    lmList=detector.findPosition(img,False)
    h,w=img.shape[:2]
    if len(lmList) !=0:
        #Right Leg (hip=24, knee=26, ankle=28)
        angle=detector.findAngle(img,24,26,28)
        # make the angle 0-180 no matter which way you face the camera
        if angle>180:
            angle=360-angle
        #Left Leg (hip=23, knee=25, ankle=27)
        angle_l=detector.findAngle(img,23,25,27)
        if angle_l>180:
            angle_l=360-angle_l
        # both legs must bend: use the straighter knee, so raising one leg can't count a rep
        angle=max(angle,angle_l)
        # smooth the angle so one jumpy frame can't change it much
        if smooth_angle is None:
            smooth_angle=angle
        smooth_angle=0.7*smooth_angle+0.3*angle
        # standing 160 = 0% , half squat 120 or deeper = 100%
        per=np.clip(np.interp(smooth_angle,(120,160),(100,0)),0,100)
        bar_top=int(h*0.2)
        bar_bottom=int(h*0.9)
        bar_x1=int(w*0.88)
        bar_x2=int(w*0.96)
        bar=np.interp(per,(0,100),(bar_bottom,bar_top))
        # print(int(smooth_angle),int(per))
        # down: must reach 100%
        if per>=100 and dir==0:
            dir=1
        # up: must come back to 0%, and at least 1 second since the last rep
        if per<=0 and dir==1:
            if time.time()-last_rep_time>1:
                count+=1
                last_rep_time=time.time()
            dir=0
        cv2.rectangle(img,(bar_x1,bar_top),(bar_x2,bar_bottom),(0,255,0),3)
        cv2.rectangle(img,(bar_x1,int(bar)),(bar_x2,bar_bottom),(0,255,0),cv2.FILLED)
        cv2.putText(img,str(int(per))+"%",(bar_x1-40,bar_top-20),cv2.FONT_HERSHEY_COMPLEX,2,(255,0,0),3)
        cv2.putText(img,str(int(count)),(20,h-40),cv2.FONT_HERSHEY_COMPLEX,4,(255,0,0),5)

    ctime=time.time()
    fps=1/(ctime-ptime)
    ptime=ctime
    cv2.putText(img,str(int(fps)), (10,70),cv2.FONT_HERSHEY_COMPLEX, 2, (255,0,255),3)
    cv2.imshow("image", img)
    cv2.waitKey(1)