import cv2, mediapipe as mp
import numpy as np
import time
import PoseModule as pm


detector= pm.PoseDetector()
cap = cv2.VideoCapture(0)
ptime=0
ctime=0
count=0
dir=0
while True:
    success, img=cap.read()
    imgRGB=cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img=detector.findPose(img)
    lmList=detector.findPosition(img,False)
    if len(lmList) !=0:
        #Right Arm
        angle=detector.findAngle(img,12,14,16)
        if angle>180:
                    angle=360-angle
        per=np.clip(np.interp(angle,(94,130),(100,0)),0,100)
        h,w=img.shape[:2]
        bar_top=int(h*0.2)
        bar_bottom=int(h*0.9)
        bar_x1=int(w*0.88)
        bar_x2=int(w*0.96)
        bar=np.interp(per,(0,100),(bar_bottom,bar_top))
        # print(per)
        if per==100:
            if dir==0:
                count+=0.5
                dir=1
        if per==0:
                    if dir==1:
                        count+=0.5
                        dir=0
        cv2.rectangle(img,(bar_x1,bar_top),(bar_x2,bar_bottom),(0,255,0),3)
        cv2.rectangle(img,(bar_x1,int(bar)),(bar_x2,bar_bottom),(0,255,0),cv2.FILLED)
        cv2.putText(img,str(int(per)),(450,70),cv2.FONT_HERSHEY_COMPLEX,3,(255,0,0),3)
        cv2.putText(img,str(int(count)),(10,450),cv2.FONT_HERSHEY_COMPLEX,3,(255,0,0),3)

    ctime=time.time()
    fps=1/(ctime-ptime)
    ptime=ctime
    cv2.putText(img,str(int(fps)), (10,70),cv2.FONT_HERSHEY_COMPLEX, 3, (255,0,255),3)
    cv2.imshow("image", img)
    cv2.waitKey(1)