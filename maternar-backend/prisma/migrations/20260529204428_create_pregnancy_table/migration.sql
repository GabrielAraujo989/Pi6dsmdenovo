-- CreateEnum
CREATE TYPE "PregnancyStatus" AS ENUM ('ativa', 'finalizada', 'interrompida');

-- CreateTable
CREATE TABLE "gestacoes" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "dum_start_date" DATE,
    "estimated_due_date" DATE,
    "status" "PregnancyStatus" NOT NULL DEFAULT 'ativa',
    "cluster_id" SMALLINT,
    "cluster_name" VARCHAR(60),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gestacoes_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "gestacoes" ADD CONSTRAINT "gestacoes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
