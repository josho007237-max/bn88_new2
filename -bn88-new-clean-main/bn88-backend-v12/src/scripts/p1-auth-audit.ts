import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const ROOT_EMAIL = "root@bn9.local";
const ROOT_PASSWORD = "bn9@12345";

async function main() {
  const users = await prisma.adminUser.findMany({
    orderBy: { createdAt: "asc" },
    select: { id: true, email: true },
  });

  console.log("[p1-auth-audit] admin users:");
  users.forEach((u) => {
    const username = u.email.split("@")[0] || null;
    const enabled = true;
    console.log({ id: u.id, email: u.email, username, enabled });
  });

  const passwordHash = await bcrypt.hash(ROOT_PASSWORD, 10);
  const root = await prisma.adminUser.upsert({
    where: { email: ROOT_EMAIL },
    update: { password: passwordHash },
    create: { email: ROOT_EMAIL, password: passwordHash },
    select: { id: true, email: true },
  });

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
    where: { adminId_roleId: { adminId: root.id, roleId: adminRole.id } },
    update: {},
    create: { adminId: root.id, roleId: adminRole.id },
  });

  console.log("[p1-auth-audit] ensured", {
    rootEmail: root.email,
    rootId: root.id,
    permission: "manageBots",
    role: "Admin",
  });
}

main()
  .catch((err) => {
    console.error("[p1-auth-audit] ERROR", err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
