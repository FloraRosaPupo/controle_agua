/*
  Warnings:

  - You are about to drop the column `lastGoalMetDate` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `level` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `streak` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `totalWater` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `xp` on the `User` table. All the data in the column will be lost.
  - You are about to drop the `Achievement` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `UserAchievement` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "UserAchievement" DROP CONSTRAINT "UserAchievement_achievementId_fkey";

-- DropForeignKey
ALTER TABLE "UserAchievement" DROP CONSTRAINT "UserAchievement_userId_fkey";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "lastGoalMetDate",
DROP COLUMN "level",
DROP COLUMN "streak",
DROP COLUMN "totalWater",
DROP COLUMN "xp",
ADD COLUMN     "quickAddAmount" INTEGER NOT NULL DEFAULT 200;

-- DropTable
DROP TABLE "Achievement";

-- DropTable
DROP TABLE "UserAchievement";
