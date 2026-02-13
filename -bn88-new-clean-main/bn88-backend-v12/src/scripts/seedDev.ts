// src/scripts/seedDev.ts
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  const email = process.env.DEV_ADMIN_EMAIL || "admin@bn9.local";
  const password = process.env.DEV_ADMIN_PASSWORD || "admin123";
  const tenant = process.env.TENANT_DEFAULT || "bn9";

  const hash = await bcrypt.hash(password, 10);

  await prisma.tenant.upsert({
    where: { code: tenant },
    update: { name: tenant, status: "active" },
    create: { code: tenant, name: tenant, status: "active" },
  });

  const admin = await prisma.adminUser.upsert({
    where: { email },
    update: { password: hash },
    create: { email, password: hash },
    select: { id: true, email: true },
  });

  // minimum RBAC for dashboard/admin APIs
  try {
    const manageBots = await prisma.permission.upsert({
      where: { name: "manageBots" },
      update: { description: "Manage bots and secrets" },
      create: { name: "manageBots", description: "Manage bots and secrets" },
      select: { id: true },
    });

    const adminRole = await prisma.role.upsert({
      where: { name: "Admin" },
      update: {},
      create: { name: "Admin", description: "Default admin role" },
      select: { id: true },
    });

    await prisma.rolePermission.upsert({
      where: {
        roleId_permissionId: {
          roleId: adminRole.id,
          permissionId: manageBots.id,
        },
      },
      update: {},
      create: {
        roleId: adminRole.id,
        permissionId: manageBots.id,
      },
    });

    await prisma.adminUserRole.upsert({
      where: { adminId_roleId: { adminId: admin.id, roleId: adminRole.id } },
      update: {},
      create: { adminId: admin.id, roleId: adminRole.id },
    });

    // keep superadmin for compatibility
    const role = await prisma.role.upsert({
      where: { name: "superadmin" },
      update: {},
      create: { name: "superadmin", description: "Full access role" },
      select: { id: true, name: true },
    });

    await prisma.adminUserRole.upsert({
      where: { adminId_roleId: { adminId: admin.id, roleId: role.id } },
      update: {},
      create: { adminId: admin.id, roleId: role.id },
    });
  } catch {
    // schema ไม่มี role tables ก็ไม่เป็นไร (ล็อกอินได้อยู่)
  }

  await prisma.bot.upsert({
    where: { tenant_name: { tenant, name: "admin-bot-001" } },
    update: {},
    create: { tenant, name: "admin-bot-001", platform: "line", active: true },
    select: { id: true },
  });

  console.log("[seedDev] OK:", {
    email: admin.email,
    adminId: admin.id,
    tenant,
  });
}

main()
  .catch((e) => {
    console.error("[seedDev] ERROR", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
