import cv2, mediapipe as mp
import time
import math



class PoseDetector():
    def __init__(self,mode=False,complexity=1,smooth_lm=True,enable_seg=False,smooth_seg=True,detection_con=0.5,tracking_con=0.5):
        self.mode=mode
        self.complexity=complexity
        self.smooth_lm=smooth_lm
        self.enable_seg=enable_seg
        self.smooth_seg=smooth_seg
        self.detection_con=detection_con
        self.tracking_con=tracking_con

        self.mpPose=mp.solutions.pose
        self.pose=self.mpPose.Pose()
        self.mpDraw=mp.solutions.drawing_utils


    def findPose(self, img,draw=True):
        imgRGB=cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        self.results=self.pose.process(imgRGB)
        if self.results.pose_landmarks:  
            if draw:    
                self.mpDraw.draw_landmarks(img, self.results.pose_landmarks, self.mpPose.POSE_CONNECTIONS)
        return img




         
    def findPosition(self,img,draw=True):
        self.lmList=[]
        if self.results.pose_landmarks:      
                myPose=self.results.pose_landmarks 
                for id , lm in enumerate(myPose.landmark):
                    #print(id,lm)
                    h,w,c =img.shape
                    cx,cy=int(lm.x*w),int(lm.y*h)
                    # print(id,cx,cy)
                    self.lmList.append([id,cx,cy])
                    if draw:
                        cv2.circle(img,(cx,cy),5,(255,0,0),cv2.FILLED)
        return self.lmList

    def findAngle(self,img,p1,p2,p3,draw=True):
        x1,y1=self.lmList[p1][1:]
        x2,y2=self.lmList[p2][1:]
        x3,y3=self.lmList[p3][1:] 
        angle= math.degrees(math.atan2(y3-y2,x3-x2)-math.atan2(y1-y2,x1-x2))
        if angle<0:
            angle+=360
        
        if draw:
            cv2.line(img,(x1,y1),(x2,y2),(0,0,0),3)
            cv2.line(img,(x3,y3),(x2,y2),(0,0,0),3)
            cv2.circle(img,(x1,y1),5,(0,0,255),cv2.FILLED)
            cv2.circle(img,(x1,y1),10,(0,0,255),2)
            cv2.circle(img,(x2,y2),5,(0,0,255),cv2.FILLED)
            cv2.circle(img,(x2,y2),10,(0,0,255),2)
            cv2.circle(img,(x3,y3),5,(0,0,255),cv2.FILLED)
            cv2.circle(img,(x3,y3),10,(0,0,255),2)
            cv2.putText(img,str(int(angle)),(x2+10,y2-30),cv2.FONT_HERSHEY_COMPLEX,1.5,(255,0,255),2)
        return angle

def main():
    cap = cv2.VideoCapture(0)
    detector=PoseDetector()
    ptime=0
    ctime=0
    while True:
        success, img=cap.read()
        img=detector.findPose(img)
        lmList=detector.findPosition(img)
        if len(lmList)!=0:
            print(lmList[4])    
        ctime=time.time()
        fps=1/(ctime-ptime)
        ptime=ctime
        cv2.putText(img,str(int(fps)), (10,70),cv2.FONT_HERSHEY_COMPLEX, 3, (255,0,255),3)
        cv2.imshow("image", img)
        cv2.waitKey(1)



if __name__ =="__main__":
    main()