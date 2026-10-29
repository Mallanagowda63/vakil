// "Today" means today in India everywhere (dashboards, lawyer earnings,
// reports): the cloud server's clock runs on UTC, which would start the day
// at 5:30 AM IST. Imported first by index.js; TZ in the environment wins.
process.env.TZ ||= 'Asia/Kolkata';
