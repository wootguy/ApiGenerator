import os, subprocess, time, psutil, sys

dat_folder = "svencoop/scripts/plugins/store/ApiGenerator/"

os.chdir("../../../../") # up to Sven Co-op folder

# automatically start api generation when map starts
file = open(os.path.join(dat_folder, '_AUTOSTART'), 'w+')
file.close()

while True:
	dirlist = os.listdir('.')
	for item in dirlist:
		if item.endswith(".mdmp"):
			try:
				os.remove(item)
			except Exception as e:
				print(e)
	
	if os.name == "nt":
		program_path = "svencoop.exe"
		arguments = ["+map", "empty", "+developer", "1", "-dll", "addons/metamod/dlls/metamod.dll"]
	else:
		program_path = "steam"
		arguments = ["-applaunch", "225840", "+map", "empty", "+developer", "1", "-dll", "addons/metamod/dlls/metamod.so"]
	
	process = subprocess.Popen([program_path] + arguments)
	pid = process.pid

	print("Started PID %d" % pid)
	
	test_fpath = os.path.join(dat_folder, "_deleteme.txt")
	
	#print("Waiting for _deleteme.txt")
	for x in range(0, 200):
		if os.path.exists(test_fpath):
			try:
				os.remove(test_fpath)
			except:
				print("Failed to remove test file.")
				continue
			print("Api generation started. Waiting...")
			
			# if this is too short, the game will keep restarting even if the api generation is able to finish
			# slow machines might need to increase this
			time.sleep(1)
			break
			
		# might need to increase this and range() above for slow machines
		if x == 199:
			print("The game is taking too long to start.")
			break
		time.sleep(0.1)
	
	if os.path.exists(test_fpath):
		os.remove(test_fpath)
		print("Api generation appears to have finished")
		break
	else:
		print("The game seems to have crashed. Killing it.")
		try:
			process = psutil.Process(pid)
			process.terminate()
		except psutil.NoSuchProcess as e:
			continue