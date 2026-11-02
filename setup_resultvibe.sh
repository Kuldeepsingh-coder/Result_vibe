#!/bin/bash
set -e
PROJECT="$HOME/linux_project/resultvibe"
mkdir -p "$PROJECT"/{lib,data,reports,backups,logs}
cd "$PROJECT"

cat > main.sh <<'MAIN'
#!/bin/bash
cd "$(dirname "$0")" || exit 1
source lib/functions.sh
case "${1:-}" in
  --help) show_help; exit 0 ;;
  --backup) do_backup; exit $? ;;
  --cron) cron_task; exit $? ;;
  "") ;;
  *) echo "Unknown argument: $1"; show_help; exit 2 ;;
esac
while true; do
  echo
  echo "========== RESULT VIBE CHECK =========="
  echo "1) Add / update a student's marks"
  echo "2) Compute total, percentage and grade"
  echo "3) Print the top 5 rank list"
  echo "4) List students failing in any subject"
  echo "5) Write a formatted result report"
  echo "6) View data"
  echo "7) Backup data (tar.gz)"
  echo "8) View activity log"
  echo "0) Exit"
  read -r -p "Choose an option: " ch
  case "$ch" in
    1) feature_1 ;;
    2) feature_2 ;;
    3) feature_3 ;;
    4) feature_4 ;;
    5) feature_5 ;;
    6) view_data ;;
    7) do_backup ;;
    8) view_log ;;
    0) echo "Bye!"; break ;;
    *) echo "Invalid choice, try again." ;;
  esac
done
MAIN

cat > lib/functions.sh <<'FUNCTIONS'
#!/bin/bash
DATA="data/marks.csv"
LOG="logs/activity.log"
log() { mkdir -p "$(dirname "$LOG")"; printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }
check_data() { [[ -f "$DATA" ]] || { echo "Data file not found: $DATA"; return 1; }; }
show_help() { cat <<'HELP'
Usage: ./main.sh [--help|--backup|--cron]
--help    Show help
--backup  Create a tar.gz backup
--cron    Generate scheduled result report
HELP
}
view_data() { check_data || return 1; cat "$DATA"; log "data viewed"; }
do_backup() {
  check_data || return 1
  mkdir -p backups
  local f="backups/data_$(date +%Y%m%d_%H%M%S).tar.gz"
  tar -czf "$f" data/ && echo "Backup saved: $f" && log "backup created $f"
}
view_log() { [[ -f "$LOG" ]] && tail -n 20 "$LOG" || echo "No activity yet."; }
feature_1() {
  check_data || return 1
  local roll name value ml linux udp os se tmp subject
  echo "== Add / update a student's marks =="
  read -r -p "Enter roll number: " roll
  read -r -p "Enter student name (no commas): " name
  if [[ -z "$roll" || -z "$name" || "$name" == *","* ]]; then echo "Roll and name are required; name must not contain commas."; log "feature_1 validation failed"; return 1; fi
  for subject in ml linux udp os se; do
    while true; do
      read -r -p "Enter $subject marks (0-100): " value
      if [[ "$value" =~ ^[0-9]{1,3}$ ]] && (( value <= 100 )); then
        case "$subject" in ml) ml=$value;; linux) linux=$value;; udp) udp=$value;; os) os=$value;; se) se=$value;; esac
        break
      fi
      echo "Enter a whole number from 0 to 100."
    done
  done
  tmp="$(mktemp)"
  awk -F',' -v r="$roll" 'NR==1 || $1!=r' "$DATA" > "$tmp"
  printf '%s,%s,%s,%s,%s,%s,%s\n' "$roll" "$name" "$ml" "$linux" "$udp" "$os" "$se" >> "$tmp"
  mv "$tmp" "$DATA"
  echo "Student marks saved (new or updated)."; log "marks saved/updated for roll $roll"
}
feature_2() {
  check_data || return 1
  echo "== Student totals, percentages and grades =="
  awk -F',' 'NR==1{next} {t=$3+$4+$5+$6+$7;p=t/5;if(p>=80)g="A";else if(p>=60)g="B";else if(p>=40)g="C";else g="F";printf "%-7s %-22s Total:%3d/500 Percentage:%6.2f%% Grade:%s\n",$1,$2,t,p,g}' "$DATA"
  log "totals percentages and grades calculated"
}
feature_3() {
  check_data || return 1
  echo "== TOP 5 STUDENTS BY TOTAL MARKS =="
  awk -F',' 'NR>1{t=$3+$4+$5+$6+$7;printf "%d,%s,%s\n",t,$1,$2}' "$DATA" | sort -t',' -k1,1nr -k2,2 | head -5 |
  awk -F',' 'BEGIN{printf "%-5s %-7s %-22s %-9s\n","RANK","ROLL","NAME","TOTAL"}{printf "%-5d %-7s %-22s %-9d\n",NR,$2,$3,$1}'
  log "top 5 rank list displayed"
}
feature_4() {
  check_data || return 1
  echo "== STUDENTS FAILING IN ANY SUBJECT (MARKS BELOW 35) =="
  awk -F',' 'NR>1{f="";for(i=3;i<=7;i++)if($i<35){if(f!="")f=f", ";f=f $i}if(f!="")printf "%-7s %-22s Failed mark(s): %s\n",$1,$2,f;else ok++}END{if(NR<=1)print "No student data found."}' "$DATA"
  log "failing students list displayed"
}
feature_5() {
  check_data || return 1
  mkdir -p reports
  local out="reports/report_$(date +%Y-%m-%d).txt"
  { echo "RESULT VIBE CHECK - STUDENT RESULT REPORT"; echo "Generated: $(date)"; echo; awk -F',' 'NR==1{next}{t=$3+$4+$5+$6+$7;p=t/5;if(p>=80)g="A";else if(p>=60)g="B";else if(p>=40)g="C";else g="F";printf "%s,%s,%s,%s,%.2f,%s\n",$1,$2,t,p,g}' "$DATA"; } > "$out"
  echo "Report saved to $out"; log "formatted result report created $out"
}
cron_task() {
  check_data || return 1
  mkdir -p reports logs
  local out="reports/result_$(date +%Y-%m-%d).txt"
  { echo "RESULT VIBE CHECK - SCHEDULED REPORT"; echo "Generated: $(date)"; echo "roll,name,total,percentage,grade"; awk -F',' 'NR==1{next}{t=$3+$4+$5+$6+$7;p=t/5;if(p>=80)g="A";else if(p>=60)g="B";else if(p>=40)g="C";else g="F";printf "%s,%s,%d,%.2f,%s\n",$1,$2,t,p,g}' "$DATA"; } > "$out"
  echo "Scheduled report generated: $out"
  echo "$(date '+%Y-%m-%d %H:%M:%S') | cron task generated $out" >> logs/cron.log
  log "cron task ran and generated $out"
}
FUNCTIONS

if [[ ! -f data/marks.csv ]]; then
cat > data/marks.csv <<'CSV'
roll,name,ml,linux,udp,os,se
H30,AKSHA MANSURI,78,85,66,72,80
H35,ARSHIYA QUAZI,45,38,52,60,49
G35,KULDEEP SINGH,88,91,84,86,90
H12,RIYA SHAH,65,72,70,68,74
H18,AARAV PATEL,92,89,95,90,94
H21,NEHA JOSHI,33,55,61,42,50
H24,DEV MEHTA,71,76,69,80,73
H29,ISHA DESAI,84,82,88,79,86
H31,ROHAN SHAH,29,44,51,32,48
H33,PRIYA NAIR,90,93,87,91,89
H36,KABIR KHAN,57,62,58,66,61
H40,ANAYA RAO,76,81,79,75,83
H41,VIVAN GUPTA,68,70,72,64,69
H43,SANA MEMON,40,37,42,39,45
H45,OM TRIVEDI,95,94,92,96,93
H47,TANVI IYER,81,77,85,82,80
H49,ARJUN REDDY,34,68,72,55,61
H51,MEERA PATEL,73,75,70,78,76
H54,YASH KAPOOR,59,61,63,58,64
H57,DIYA SHARMA,86,88,84,90,87
H60,ADITYA JAIN,48,52,45,50,54
H62,NISHA VERMA,67,69,71,65,70
H65,KRISHNA DAS,22,30,42,28,35
H68,ZARA KHAN,79,83,80,77,82
H70,MANAV SINGH,62,58,66,64,60
H72,KAVYA NAIR,91,87,89,93,90
H75,ISHAN DESAI,55,47,52,49,58
H78,AANYA SHAH,83,85,81,88,84
H80,REHAN ALI,38,42,33,45,40
H82,SIMRAN KAUR,74,79,76,72,78
CSV
fi
cat > README.md <<'README'
# L02 – Result Vibe Check
Student marks analysis in Bash.
Columns: roll, name, ml, linux, udp, os, se. Marks are 0–100.
Grade rule: A >= 80%, B >= 60%, C >= 40%, otherwise F.
Fail list: any subject mark below 35.
Run: `./main.sh`
Test: `./main.sh --help`, `./main.sh --backup`, `./main.sh --cron`.
README
: > logs/activity.log
chmod +x main.sh lib/functions.sh
echo "Project created at: $PROJECT"
echo "Run it with: cd \"$PROJECT\" && ./main.sh"
echo "Test cron output with: cd \"$PROJECT\" && ./main.sh --cron"
