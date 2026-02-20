# WORKLIST-REMAINING

อัปเดตจากสถานะล่าสุด (หลัง commit `6f45609`)

## ✅ Done
- Chat route alias รองรับทั้ง `/api/admin/chat` และ `/api/admin/chats`
- `p0-chat-smoke`
- `p0-cd-guard`
- `p0-jump-backend`
- FE `VITE_API_BASE`

## 🔜 Remaining (เรียงตามลำดับความสำคัญ)

### 1) Phase 7: LINE Webhook E2E
ขอบเขต: tunnel + verify signature (raw body) + save DB + SSE + reply ส่ง LINE

**Acceptance Criteria**
- เปิด tunnel แล้ว LINE ส่ง webhook เข้า endpoint ได้จริง (HTTP 200)
- Backend verify ลายเซ็นจาก raw body ได้ถูกต้อง
- Event ถูกบันทึกลง DB ครบฟิลด์หลักที่ระบบใช้งาน
- FE/consumer ได้ SSE event ที่เกี่ยวข้องแบบ end-to-end
- ระบบ reply กลับ LINE สำเร็จ (มีหลักฐานจาก log/response)

**PowerShell Test Commands**
```powershell
cd "C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12"
$env:LINE_CHANNEL_SECRET="<secret>"
$env:LINE_CHANNEL_ACCESS_TOKEN="<token>"
npm run dev

# เปิด tunnel (อีกหน้าต่าง)
cd "C:\Go23_th\bn88_new2\-bn88-new-clean-main"
.\run-tunnel.ps1

# ตรวจ endpoint health/behavior (ปรับ URL ตาม tunnel)
Invoke-WebRequest -Uri "https://<tunnel>/api/webhooks/line" -Method Post -ContentType "application/json" -Body '{"events":[]}'
```

---

### 2) Phase 8: Attachments
ขอบเขต: `line-content` ตอบ 200 + FE ใช้ fetch -> blob -> objectURL

**Acceptance Criteria**
- API `line-content` ตอบ 200 และ `Content-Type` ถูกต้องตามไฟล์
- FE โหลดไฟล์แนบผ่าน `fetch` แล้วสร้าง `blob`/`objectURL` แสดงผลได้
- กรณีไฟล์หาย/หมดอายุ token แสดงสถานะผิดพลาดที่เข้าใจได้

**PowerShell Test Commands**
```powershell
cd "C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12"
# ตัวอย่างเรียก line-content (ต้องแทนค่า id/token ตามจริง)
Invoke-WebRequest -Uri "http://localhost:3000/api/admin/line-content/<messageId>" -OutFile ".\tmp.bin"

# เปิด FE เพื่อตรวจผล objectURL rendering
cd "C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-frontend-dashboard-v12"
npm run dev
```

---

### 3) FE token single key + SSE reconnect UI

**Acceptance Criteria**
- FE ใช้ token key เดียวอย่างสม่ำเสมอทั้ง read/write
- รีโหลดหน้าแล้ว auth state ไม่หลุดจาก key mismatch
- เมื่อ SSE หลุด มีสถานะบน UI และ reconnect อัตโนมัติจนกลับมา online
- เมื่อ reconnect สำเร็จ UI อัปเดตสถานะชัดเจน

**PowerShell Test Commands**
```powershell
cd "C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-frontend-dashboard-v12"
npm run dev

# ตรวจ key ใน browser devtools localStorage ให้เหลือ key เดียวตามที่กำหนด
# ทดสอบ SSE reconnect โดยปิด/เปิด backend ชั่วคราว แล้วดูสถานะ UI
```

## Constraints
- ห้ามเปลี่ยน API
- ห้ามรื้อโครงสร้างใหญ่
- ทำแบบ minimal diff
