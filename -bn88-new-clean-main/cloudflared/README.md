# Cloudflare Tunnel (permanent)

ใช้ไฟล์ config นี้สำหรับ tunnel ที่สร้างไว้แล้ว (`bn88-api`):

```powershell
cloudflared tunnel --config .\cloudflared\config-bn88-api.yml run bn88-api
```

> หมายเหตุ: ปรับ `credentials-file` ใน `config-bn88-api.yml` ให้ตรงกับเครื่องจริงก่อนใช้งาน
