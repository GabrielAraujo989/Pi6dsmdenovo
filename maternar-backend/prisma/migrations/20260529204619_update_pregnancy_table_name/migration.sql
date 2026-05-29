/*
  Warnings:

  - You are about to drop the `gestacoes` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "gestacoes" DROP CONSTRAINT "gestacoes_user_id_fkey";

-- DropTable
DROP TABLE "gestacoes";

-- CreateTable
CREATE TABLE "pregnancies" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "dum_start_date" DATE,
    "estimated_due_date" DATE,
    "status" "PregnancyStatus" NOT NULL DEFAULT 'ativa',
    "cluster_id" SMALLINT,
    "cluster_name" VARCHAR(60),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pregnancies_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "pregnancies" ADD CONSTRAINT "pregnancies_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
