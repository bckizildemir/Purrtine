# Usage: python3 -I Scripts/agents/last.py <sessionId> [n]
# Prints the last n (default 3) assistant text messages of a Claude Code session transcript,
# each cut to 3000 characters.
import json,sys,glob,os
sid=sys.argv[1]; n=int(sys.argv[2]) if len(sys.argv)>2 else 3
fs=glob.glob(os.path.expanduser(f"~/.claude/projects/*/{sid}*.jsonl"))
fs.sort(key=os.path.getmtime)
texts=[]
for line in open(fs[-1]):
    try: d=json.loads(line)
    except: continue
    if d.get("type")=="assistant":
        for c in d.get("message",{}).get("content",[]):
            if c.get("type")=="text" and c["text"].strip(): texts.append(c["text"])
for t in texts[-n:]: print("-----\n"+t[:3000])
