/*
  Warnings:

  - Added the required column `zip_code` to the `users` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "users" ADD COLUMN     "education_level" INTEGER,
ADD COLUMN     "had_previous_complication" BOOLEAN,
ADD COLUMN     "height" DECIMAL(65,30),
ADD COLUMN     "phone" TEXT,
ADD COLUMN     "previous_pregnancies" INTEGER,
ADD COLUMN     "weight" DECIMAL(65,30),
ADD COLUMN     "zip_code" TEXT NOT NULL;

-- CreateTable
CREATE TABLE "user_locations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "city" TEXT NOT NULL,
    "uf" VARCHAR(2) NOT NULL,
    "region" TEXT,
    "ibge_code" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_locations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_locations_user_id_key" ON "user_locations"("user_id");

-- AddForeignKey
ALTER TABLE "user_locations" ADD CONSTRAINT "user_locations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
