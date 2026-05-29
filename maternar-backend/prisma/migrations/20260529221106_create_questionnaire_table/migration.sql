-- CreateTable
CREATE TABLE "questionnaires" (
    "id" UUID NOT NULL,
    "pregnancy_id" UUID NOT NULL,
    "current_weight" DECIMAL(5,2) NOT NULL,
    "current_appointments" SMALLINT NOT NULL,
    "had_new_complications" BOOLEAN NOT NULL,
    "anti_hiv_flag" SMALLINT NOT NULL,
    "cluster_id" SMALLINT,
    "cluster_name" VARCHAR(60),
    "calculated_imc" DECIMAL(5,2),
    "response_date" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "questionnaires_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "questionnaires" ADD CONSTRAINT "questionnaires_pregnancy_id_fkey" FOREIGN KEY ("pregnancy_id") REFERENCES "pregnancies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
