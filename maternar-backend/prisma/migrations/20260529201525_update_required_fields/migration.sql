/*
  Warnings:

  - Made the column `education_level` on table `users` required. This step will fail if there are existing NULL values in that column.
  - Made the column `race_color` on table `users` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterTable
ALTER TABLE "users" ALTER COLUMN "education_level" SET NOT NULL,
ALTER COLUMN "race_color" SET NOT NULL;
