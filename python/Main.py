print("Choose your training:")
print("1 - Biceps Curl")
print("2 - Squat")
print("3 - Deadlift")
print("4 - Bench Press")

choice=input("Enter a number (1-4): ")
while choice not in ["1","2","3","4"]:
    choice=input("Wrong choice, enter a number (1-4): ")

# importing the file runs it
if choice=="1":
    import AiTrainer
elif choice=="2":
    import SquatTrainer
elif choice=="3":
    import DeadliftTrainer
elif choice=="4":
    import BenchPressTrainer
