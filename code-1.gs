/**
 * ╔══════════════════════════════════════════════════════╗
 * ║         EARNIX — Google Apps Script Backend          ║
 * ║         Data file: dtfy.json (Google Drive)          ║
 * ╚══════════════════════════════════════════════════════╝
 *
 * DEPLOY INSTRUCTIONS:
 *  1. Go to script.google.com → New project
 *  2. Paste this entire file → Save (Ctrl+S)
 *  3. Run → setupDatabase() once (creates dtfy.json)
 *  4. Deploy → New Deployment → Web App
 *     Execute as: Me | Who has access: Anyone
 *  5. Copy the /exec URL into earnix.html and admin.html
 *
 * IMPORTANT: After any code change, always create a
 *            NEW deployment version — not edit existing.
 */

const DB_FILE = "dttttfy.json";

function respond(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

function getFile() {
  const f = DriveApp.getFilesByName(DB_FILE);
  return f.hasNext() ? f.next() : null;
}

function readDb() {
  const file = getFile();
  if (!file) throw new Error("dtfy.json not found. Run setupDatabase() first.");
  return JSON.parse(file.getBlob().getDataAsString());
}

function writeDb(data) {
  const file = getFile();
  if (!file) throw new Error("dtfy.json not found. Run setupDatabase() first.");
  file.setContent(JSON.stringify(data, null, 2));
}

// ── Run ONCE from Script Editor ──
function setupDatabase() {
  if (getFile()) { Logger.log("dtfy.json already exists."); return; }

  const seed = {
    admins: [{ id:"adm_1", username:"admin", password:"admin123", role:"superadmin" }],
    users: [{
      uid:"usr_founder", username:"founder", phone:"08000000000",
      password:"founder123", balance:0, level:0,
      referral_code:"EARNIX2024", referred_by:null,
      registered_at:new Date().toISOString(),
      tasks_completed_today:0, last_task_date:null, suspended:false
    }],
    tasks: [
      { id:"t1", title:"Watch TikTok Video",        platform:"TikTok",    reward:1200,  link:"https://tiktok.com",    level_required:1, active:true },
      { id:"t2", title:"Subscribe YouTube Channel", platform:"YouTube",   reward:5000,  link:"https://youtube.com",   level_required:2, active:true },
      { id:"t3", title:"Follow Instagram Account",  platform:"Instagram", reward:1200,  link:"https://instagram.com", level_required:1, active:true },
      { id:"t4", title:"Like Facebook Page",        platform:"Facebook",  reward:10000, link:"https://facebook.com",  level_required:3, active:true },
      { id:"t5", title:"Follow Twitter Account",    platform:"Twitter",   reward:1200,  link:"https://twitter.com",   level_required:1, active:true }
    ],
    levels: [
      { level:0, name:"Free",     deposit:0,       per_order:0,     daily_tasks:0 },
      { level:1, name:"Bronze",   deposit:12000,   per_order:1200,  daily_tasks:2 },
      { level:2, name:"Silver",   deposit:100000,  per_order:5000,  daily_tasks:4 },
      { level:3, name:"Gold",     deposit:250000,  per_order:10000, daily_tasks:5 },
      { level:4, name:"Platinum", deposit:500000,  per_order:20000, daily_tasks:5 },
      { level:5, name:"Diamond",  deposit:1000000, per_order:25000, daily_tasks:8 },
      { level:6, name:"Elite",    deposit:1800000, per_order:40000, daily_tasks:9 }
    ],
    transactions: [],
    announcements: [{ id:"ann_1", message:"🎉 Welcome to Earnix! Complete tasks daily to earn real money.", active:true }],
    settings: {
      site_name:"Earnix", tagline:"Earn Daily. Earn Smart.", site_url:"",
      bank_name:"First Bank Nigeria", bank_account:"3099887766",
      bank_account_name:"Earnix Platform Ltd",
      min_deposit:1000, min_withdraw:1000, referral_bonus_pct:5,
      maintenance:false, maintenance_msg:"Under maintenance. Please check back shortly.",
      support_email:"support@earnix.app", support_whatsapp:""
    }
  };

  DriveApp.createFile(DB_FILE, JSON.stringify(seed, null, 2), MimeType.PLAIN_TEXT);
  Logger.log("✅ dtfy.json created successfully!");
}

// ── doGet: Read DB + GET action routes ──
function doGet(e) {
  const p = e.parameter || {};
  try {
    const db = readDb();
    if (db.settings?.maintenance && p.role !== "admin")
      return respond({ error:"maintenance", message:db.settings.maintenance_msg });

    switch (p.action) {
      case "login": {
        if (!p.phone || !p.password) return respond({ success:false, error:"Phone and password required" });
        const u = (db.users||[]).find(u => u.phone===p.phone && u.password===p.password);
        if (!u) return respond({ success:false, error:"Invalid phone number or password" });
        if (u.suspended) return respond({ success:false, error:"Account suspended. Contact support." });
        return respond({ success:true, user:u });
      }
      case "register": {
        const users = db.users||[];
        if (!p.phone||!p.password||!p.username||!p.referral_code)
          return respond({ success:false, error:"All fields including referral code are required" });
        if (users.find(u=>u.phone===p.phone))
          return respond({ success:false, error:"Phone number already registered" });
        if (users.find(u=>u.username&&u.username.toLowerCase()===p.username.toLowerCase()))
          return respond({ success:false, error:"Username already taken" });
        const referrer = users.find(u=>u.referral_code===p.referral_code.toUpperCase());
        if (!referrer) return respond({ success:false, error:"Invalid referral code. A valid code is required to join." });
        const clean = p.username.toUpperCase().replace(/[^A-Z0-9]/g,"").slice(0,4);
        const newUser = {
          uid:"usr_"+Date.now(), username:p.username, phone:p.phone, password:p.password,
          balance:0, level:0,
          referral_code:clean+Math.floor(1000+Math.random()*9000),
          referred_by:p.referral_code.toUpperCase(),
          registered_at:new Date().toISOString(),
          tasks_completed_today:0, last_task_date:null, suspended:false
        };
        db.users.push(newUser);
        writeDb(db);
        return respond({ success:true, user:newUser });
      }
      case "adminLogin": {
        const a = (db.admins||[]).find(a=>a.username===p.username&&a.password===p.password);
        if (!a) return respond({ success:false, error:"Invalid admin credentials" });
        return respond({ success:true, admin:a });
      }
      default:
        return respond(db);
    }
  } catch(err) { return respond({ error:err.message }); }
}

// ── doPost: Write actions ──
// Frontend sends Content-Type: text/plain to avoid CORS preflight
// Body is still valid JSON string
function doPost(e) {
  try {
    const body   = JSON.parse(e.postData.contents);
    const action = body.action;
    const db     = readDb();

    switch(action) {

      case "completeTask": {
        const user = db.users.find(u=>u.uid===body.uid);
        if (!user) return respond({ success:false, error:"User not found" });
        const task = db.tasks.find(t=>t.id===body.task_id);
        if (!task||!task.active) return respond({ success:false, error:"Task not available" });
        if (task.level_required>(user.level||0)) return respond({ success:false, error:"VIP level too low" });
        const today = new Date().toISOString().slice(0,10);
        const max   = db.levels.find(l=>l.level===(user.level||0))?.daily_tasks||0;
        if (user.last_task_date!==today){ user.tasks_completed_today=0; user.last_task_date=today; }
        if ((user.tasks_completed_today||0)>=max) return respond({ success:false, error:"Daily task limit reached ("+max+"/day)" });
        user.balance = (user.balance||0)+task.reward;
        user.tasks_completed_today = (user.tasks_completed_today||0)+1;
        user.last_task_date = today;
        if (user.referred_by) {
          const ref = db.users.find(u=>u.referral_code===user.referred_by);
          if (ref) ref.balance=(ref.balance||0)+Math.floor(task.reward*(db.settings?.referral_bonus_pct||5)/100);
        }
        writeDb(db);
        return respond({ success:true, user });
      }

      case "deposit": {
        const user = db.users.find(u=>u.uid===body.uid);
        if (!user) return respond({ success:false, error:"User not found" });
        const min = db.settings?.min_deposit||1000;
        if (!body.amount||body.amount<min) return respond({ success:false, error:"Minimum deposit is ₦"+min });
        const txn={ id:"txn_"+Date.now(), user_id:body.uid, type:"deposit",
          amount:Number(body.amount), status:"pending", timestamp:new Date().toISOString() };
        db.transactions=db.transactions||[];
        db.transactions.push(txn);
        writeDb(db);
        return respond({ success:true, txn });
      }

      case "withdraw": {
        const user = db.users.find(u=>u.uid===body.uid);
        if (!user) return respond({ success:false, error:"User not found" });
        const min = db.settings?.min_withdraw||1000;
        if (!body.amount||body.amount<min) return respond({ success:false, error:"Minimum withdrawal is ₦"+min });
        if (body.amount>(user.balance||0)) return respond({ success:false, error:"Insufficient balance" });
        if (!body.bank_name||!body.account_number||!body.account_name) return respond({ success:false, error:"All bank details required" });
        user.balance=(user.balance||0)-Number(body.amount);
        const txn={ id:"txn_"+Date.now(), user_id:body.uid, type:"withdrawal",
          amount:Number(body.amount), status:"pending",
          bank_name:body.bank_name, account_number:body.account_number, account_name:body.account_name,
          timestamp:new Date().toISOString() };
        db.transactions=db.transactions||[];
        db.transactions.push(txn);
        writeDb(db);
        return respond({ success:true, txn, user });
      }

      case "saveDb": {
        if (!body.db) return respond({ success:false, error:"No data" });
        writeDb(body.db);
        return respond({ success:true });
      }

      case "approveDeposit": {
        const txn = db.transactions.find(t=>t.id===body.txn_id);
        if (!txn) return respond({ success:false, error:"Transaction not found" });
        if (txn.status!=="pending") return respond({ success:false, error:"Already "+txn.status });
        txn.status="approved";
        const user = db.users.find(u=>u.uid===txn.user_id);
        if (user) {
          user.balance=(user.balance||0)+txn.amount;
          const totDep=db.transactions.filter(t=>t.user_id===user.uid&&t.type==="deposit"&&t.status==="approved").reduce((s,t)=>s+t.amount,0);
          const nlvl=[...(db.levels||[])].sort((a,b)=>b.deposit-a.deposit).find(l=>totDep>=l.deposit);
          if (nlvl&&nlvl.level>(user.level||0)) user.level=nlvl.level;
          if (user.referred_by) {
            const ref=db.users.find(u=>u.referral_code===user.referred_by);
            if (ref) ref.balance=(ref.balance||0)+Math.floor(txn.amount*(db.settings?.referral_bonus_pct||5)/100);
          }
        }
        writeDb(db);
        return respond({ success:true });
      }

      case "rejectDeposit": {
        const txn=db.transactions.find(t=>t.id===body.txn_id);
        if (!txn) return respond({ success:false, error:"Transaction not found" });
        if (txn.status!=="pending") return respond({ success:false, error:"Already "+txn.status });
        txn.status="rejected"; txn.reject_reason=body.reason||null;
        writeDb(db);
        return respond({ success:true });
      }

      case "approveWithdrawal": {
        const txn=db.transactions.find(t=>t.id===body.txn_id);
        if (!txn) return respond({ success:false, error:"Transaction not found" });
        if (txn.status!=="pending") return respond({ success:false, error:"Already "+txn.status });
        txn.status="approved";
        writeDb(db);
        return respond({ success:true });
      }

      case "rejectWithdrawal": {
        const txn=db.transactions.find(t=>t.id===body.txn_id);
        if (!txn) return respond({ success:false, error:"Transaction not found" });
        if (txn.status!=="pending") return respond({ success:false, error:"Already "+txn.status });
        txn.status="rejected"; txn.reject_reason=body.reason||null;
        const user=db.users.find(u=>u.uid===txn.user_id);
        if (user) user.balance=(user.balance||0)+txn.amount;
        writeDb(db);
        return respond({ success:true });
      }

      case "updateUser": {
        const idx=db.users.findIndex(u=>u.uid===body.user.uid);
        if (idx===-1) return respond({ success:false, error:"User not found" });
        db.users[idx]={...db.users[idx],...body.user};
        writeDb(db); return respond({ success:true });
      }

      case "deleteUser": {
        db.users=db.users.filter(u=>u.uid!==body.uid);
        writeDb(db); return respond({ success:true });
      }

      case "saveTask": {
        db.tasks=db.tasks||[];
        const idx=db.tasks.findIndex(t=>t.id===body.task.id);
        if (idx>=0) db.tasks[idx]=body.task; else db.tasks.push(body.task);
        writeDb(db); return respond({ success:true });
      }

      case "deleteTask": {
        db.tasks=db.tasks.filter(t=>t.id!==body.task_id);
        writeDb(db); return respond({ success:true });
      }

      case "saveSettings": {
        db.settings={...db.settings,...body.settings};
        writeDb(db); return respond({ success:true });
      }

      case "saveAnnouncement": {
        db.announcements=db.announcements||[];
        const idx=db.announcements.findIndex(a=>a.id===body.announcement.id);
        if (idx>=0) db.announcements[idx]=body.announcement; else db.announcements.push(body.announcement);
        writeDb(db); return respond({ success:true });
      }

      case "saveLevels": {
        db.levels=body.levels;
        writeDb(db); return respond({ success:true });
      }

      case "adjustBalance": {
        const user=db.users.find(u=>u.uid===body.uid);
        if (!user) return respond({ success:false, error:"User not found" });
        const before=user.balance||0;
        if (body.type==="add")           user.balance=before+Number(body.amount);
        else if (body.type==="subtract") user.balance=Math.max(0,before-Number(body.amount));
        else if (body.type==="set")      user.balance=Number(body.amount);
        db.transactions.push({ id:"txn_"+Date.now(), user_id:body.uid, type:"deposit",
          amount:Number(body.amount), status:"approved",
          note:"Admin adjustment: "+(body.reason||""), timestamp:new Date().toISOString() });
        writeDb(db); return respond({ success:true, user });
      }

      default:
        return respond({ success:false, error:"Unknown action: "+action });
    }
  } catch(err) { return respond({ success:false, error:err.message }); }
}
