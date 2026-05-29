/*
  Warnings:

  - You are about to drop the column `weight` on the `users` table. All the data in the column will be lost.
  - Added the required column `updated_at` to the `users` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "users" DROP COLUMN "weight",
ADD COLUMN     "pre_gestational_weight" DECIMAL(65,30),
ADD COLUMN     "race_color" INTEGER,
ADD COLUMN     "updated_at" TIMESTAMP(3) NOT NULL;
