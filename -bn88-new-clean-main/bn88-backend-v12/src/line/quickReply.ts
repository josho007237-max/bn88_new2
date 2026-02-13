export type Lang = "th" | "lo";

export function buildQuickReplyMenu(lang: Lang = "th", baseUrl = "") {
  const t = (th: string, lo: string) => (lang === "lo" ? lo : th);

  const liffUrl = baseUrl ? `${baseUrl}/liff/` : "/liff/";

  return {
    items: [
      {
        type: "action",
        action: {
          type: "postback",
          label: t("ฝากไม่เข้า", "ຝາກບໍ່ເຂົ້າ"),
          data: "case=deposit",
          displayText: t("ฝากไม่เข้า", "ຝາກບໍ່ເຂົ້າ"),
        },
      },
      {
        type: "action",
        action: {
          type: "postback",
          label: t("ถอนไม่ได้", "ຖອນບໍ່ໄດ້"),
          data: "case=withdraw",
          displayText: t("ถอนไม่ได้", "ຖອນບໍ່ໄດ້"),
        },
      },
      {
        type: "action",
        action: {
          type: "postback",
          label: t("ยืนยันตัวตน", "ຢືນຢັນຕົວຕົນ"),
          data: "case=kyc",
          displayText: t("ยืนยันตัวตน", "ຢືນຢັນຕົວຕົນ"),
        },
      },
      {
        type: "action",
        action: {
          type: "uri",
          label: t("เปิดฟอร์ม", "ເປີດຟອມ"),
          uri: liffUrl,
        },
      },
    ],
  };
}
