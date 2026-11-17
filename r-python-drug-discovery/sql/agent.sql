-- Optional Aromatase analyst. Run after notebooks 01 and 02 and functions.sql.
USE ROLE QSAR_ROLE;
USE WAREHOUSE QSAR_WH;
USE SCHEMA QSAR_DB.PUBLIC;

-- Create AROMATASE_SV from the Apache Ossie 0.1.1 specification (agent/aromatase_sv_ossie.yaml)
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_OSSIE_YAML('QSAR_DB.PUBLIC', $$
version: 0.1.1
semantic_model:
  - name: AROMATASE_SV
    description: "Measured human aromatase bioactivity and model scores; compound grain, one selected assay per compound. Training and test rows are mixed."
    datasets:
      - name: ASSAYS
        source: QSAR_DB.PUBLIC.CHEMBL1978_ASSAYS
        primary_key:
          - ASSAY_CHEMBL_ID
        fields:
          - name: ASSAY_DESCRIPTION
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: assays.DESCRIPTION
            dimension: {}
          - name: ASSAY_ID
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: assays.ASSAY_CHEMBL_ID
            dimension: {}
          - name: ASSAY_TYPE
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: assays.ASSAY_TYPE
            dimension: {}
      - name: COMPOUNDS
        source: QSAR_DB.PUBLIC.CHEMBL1978_COMPOUNDS
        primary_key:
          - MOLECULE_CHEMBL_ID
        fields:
          - name: ACTIVITY_LABEL
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: CASE WHEN compounds.ACTIVITY_CLASS = 1 THEN 'Active' ELSE 'Inactive' END
            dimension: {}
          - name: MOLECULE_ID
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: compounds.MOLECULE_CHEMBL_ID
            dimension: {}
          - name: SMILES
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: compounds.CANONICAL_SMILES
            dimension: {}
          - name: ACTIVE_FLAG
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: compounds.ACTIVITY_CLASS
          - name: MEASURED_PIC50
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: compounds.PCHEMBL_VALUE
      - name: DESCRIPTORS
        source: QSAR_DB.PUBLIC.CHEMBL1978_DESCRIPTORS
        primary_key:
          - MOLECULE_CHEMBL_ID
        fields:
          - name: RO5_PASS
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: descriptors.RO5_PASS
            dimension: {}
          - name: HBA
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: descriptors.HBA
          - name: HBD
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: descriptors.HBD
          - name: LOGP
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: descriptors.LOGP
          - name: MOLECULAR_WEIGHT
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: descriptors.MW
          - name: RO5_VIOLATIONS
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: descriptors.RO5_VIOLATIONS
          - name: TPSA
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: descriptors.TPSA
      - name: DOCUMENTS
        source: QSAR_DB.PUBLIC.CHEMBL1978_DOCUMENTS
        primary_key:
          - DOCUMENT_CHEMBL_ID
        fields:
          - name: DOCUMENT_ID
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: documents.DOCUMENT_CHEMBL_ID
            dimension: {}
          - name: JOURNAL
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: documents.JOURNAL
            dimension: {}
          - name: PUBLICATION_YEAR
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: TRY_TO_NUMBER(documents.YEAR)
            dimension: {}
          - name: TITLE
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: documents.TITLE
            dimension: {}
      - name: FINGERPRINTS
        source: QSAR_DB.PUBLIC.CHEMBL1978_FINGERPRINTS
        primary_key:
          - MOLECULE_CHEMBL_ID
        fields:
          - name: BIT_COUNT
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: ARRAY_SIZE(fingerprints.ECFP4_BITS)
      - name: PREDICTIONS
        source: QSAR_DB.PUBLIC.CHEMBL1978_PREDICTIONS
        primary_key:
          - MOLECULE_CHEMBL_ID
        fields:
          - name: PREDICTED_PIC50
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: predictions.PRED_PIC50
          - name: PREDICTION_ERROR
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: predictions.ERROR
      - name: PREDICTION_LOG
        source: QSAR_DB.PUBLIC.QSAR_PREDICTIONS_LOG
        primary_key:
          - PREDICTION_ID
        fields:
          - name: PREDICTED_AT
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: prediction_log.PREDICTED_AT
            dimension: {}
          - name: SERVICE_USER
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: prediction_log.USER_NAME
            dimension: {}
          - name: PREDICTED_PIC50
            expression:
              dialects:
                - dialect: SNOWFLAKE
                  expression: prediction_log.PREDICTED_PIC50
    relationships:
      - name: ASSAYS_TO_DOCUMENTS
        from: ASSAYS
        to: DOCUMENTS
        from_columns:
          - DOCUMENT_CHEMBL_ID
        to_columns:
          - DOCUMENT_CHEMBL_ID
      - name: COMPOUNDS_TO_ASSAYS
        from: COMPOUNDS
        to: ASSAYS
        from_columns:
          - ASSAY_CHEMBL_ID
        to_columns:
          - ASSAY_CHEMBL_ID
      - name: DESCRIPTORS_TO_COMPOUNDS
        from: DESCRIPTORS
        to: COMPOUNDS
        from_columns:
          - MOLECULE_CHEMBL_ID
        to_columns:
          - MOLECULE_CHEMBL_ID
      - name: FINGERPRINTS_TO_COMPOUNDS
        from: FINGERPRINTS
        to: COMPOUNDS
        from_columns:
          - MOLECULE_CHEMBL_ID
        to_columns:
          - MOLECULE_CHEMBL_ID
      - name: PREDICTIONS_TO_COMPOUNDS
        from: PREDICTIONS
        to: COMPOUNDS
        from_columns:
          - MOLECULE_CHEMBL_ID
        to_columns:
          - MOLECULE_CHEMBL_ID
    metrics:
      - name: compound_count
        expression:
          dialects:
            - dialect: SNOWFLAKE
              expression: COUNT(compounds.molecule_id)
        description: Total number of deduplicated aromatase compounds
      - name: active_count
        expression:
          dialects:
            - dialect: SNOWFLAKE
              expression: SUM(compounds.active_flag)
        description: Number of measured active compounds (pIC50 >= 6.5)
      - name: mean_measured_pic50
        expression:
          dialects:
            - dialect: SNOWFLAKE
              expression: AVG(compounds.measured_pic50)
        description: Mean measured pIC50 across compounds
      - name: mean_predicted_pic50
        expression:
          dialects:
            - dialect: SNOWFLAKE
              expression: AVG(predictions.predicted_pic50)
        description: Mean predicted pIC50 from the R QSAR model
      - name: rmse
        expression:
          dialects:
            - dialect: SNOWFLAKE
              expression: SQRT(AVG(POWER(predictions.prediction_error, 2)))
        description: Root mean squared error across scored compounds
      - name: ro5_pass_count
        expression:
          dialects:
            - dialect: SNOWFLAKE
              expression: COUNT_IF(descriptors.ro5_pass)
        description: Number of compounds passing Lipinski's Rule of Five
      - name: mean_bits_on
        expression:
          dialects:
            - dialect: SNOWFLAKE
              expression: AVG(fingerprints.bit_count)
        description: Mean number of active ECFP4 bits per molecule
      - name: request_count
        expression:
          dialects:
            - dialect: SNOWFLAKE
              expression: COUNT(prediction_log.predicted_at)
        description: Total logged prediction requests
    custom_extensions:
      - vendor_name: SNOWFLAKE
        data: '{"verified_queries":[{"name":"COMPOUND_TOTALS","sql":"SELECT * FROM SEMANTIC_VIEW(QSAR_DB.PUBLIC.AROMATASE_SV METRICS compound_count, active_count)","question":"How many compounds and actives are in the aromatase dataset?","use_as_onboarding_question":true},{"name":"ACTIVITY_BREAKDOWN","sql":"SELECT * FROM SEMANTIC_VIEW(QSAR_DB.PUBLIC.AROMATASE_SV DIMENSIONS compounds.activity_label METRICS compound_count)","question":"How many active and inactive aromatase compounds are there?"},{"name":"RO5_TOTAL","sql":"SELECT * FROM SEMANTIC_VIEW(QSAR_DB.PUBLIC.AROMATASE_SV METRICS ro5_pass_count)","question":"How many compounds pass the Rule of Five?"}]}'
$$);

-- One search row per measured molecule and assay. Repeated raw measurements
-- for the same molecule, assay and document are deduplicated by SELECT DISTINCT.
CREATE OR REPLACE CORTEX SEARCH SERVICE ASSAY_SEARCH
  ON SEARCH_TEXT
  ATTRIBUTES MOLECULE_CHEMBL_ID, ASSAY_CHEMBL_ID, DOCUMENT_CHEMBL_ID
  WAREHOUSE = QSAR_WH
  TARGET_LAG = '1 day'
  AS
  SELECT DISTINCT
    r.MOLECULE_CHEMBL_ID,
    r.ASSAY_CHEMBL_ID,
    a.DOCUMENT_CHEMBL_ID,
    CONCAT_WS(' | ', 'Assay ID: ' || r.ASSAY_CHEMBL_ID,
              'Publication ID: ' || COALESCE(a.DOCUMENT_CHEMBL_ID, 'unknown'),
              COALESCE(a.DESCRIPTION, ''), COALESCE(d.TITLE, ''),
              COALESCE(d.ABSTRACT, ''), COALESCE(d.JOURNAL, '')) AS SEARCH_TEXT
  FROM CHEMBL1978_RAW_ACTIVITIES r
  JOIN CHEMBL1978_ASSAYS a ON r.ASSAY_CHEMBL_ID = a.ASSAY_CHEMBL_ID
  LEFT JOIN CHEMBL1978_DOCUMENTS d ON a.DOCUMENT_CHEMBL_ID = d.DOCUMENT_CHEMBL_ID;

-- One SMILES per line; the generic agent tool passes one string argument.
-- Novelty compares against all measured compounds (training and held-out rows).
-- It is a similarity heuristic, not a validated applicability domain.
CREATE OR REPLACE PROCEDURE TRIAGE_COMPOUNDS(smiles_list VARCHAR)
  RETURNS VARIANT
  LANGUAGE SQL
  EXECUTE AS OWNER
AS $$
DECLARE
  results ARRAY DEFAULT ARRAY_CONSTRUCT();
  input_rows ARRAY;
  entry VARCHAR;
  predicted VARIANT;
  nearest VARIANT;
  properties VARIANT;
  similarity FLOAT;
  ranking FLOAT;
  reason VARCHAR;
BEGIN
  input_rows := SPLIT(:smiles_list, '\n');
  IF (ARRAY_SIZE(:input_rows) > 20) THEN
    RETURN OBJECT_CONSTRUCT('error', 'At most 20 SMILES per request');
  END IF;
  FOR idx IN 0 TO ARRAY_SIZE(:input_rows) - 1 DO
    entry := TRIM(input_rows[idx]::VARCHAR);
    IF (entry <> '') THEN
      SELECT PREDICT_PIC50(:entry), SIMILAR_COMPOUNDS(:entry, 1), RO5(:entry)
        INTO :predicted, :nearest, :properties;
      IF (predicted:error IS NOT NULL OR properties:error IS NOT NULL) THEN
        results := ARRAY_APPEND(:results,
          OBJECT_CONSTRUCT('smiles', :entry, 'error', 'Invalid SMILES'));
      ELSE
        similarity := nearest:max_tanimoto::FLOAT;
        ranking := predicted:pic50::FLOAT - IFF(similarity < 0.4, 1.0, IFF(similarity < 0.6, 0.5, 0.0))
                   - 0.25 * properties:ro5_violations::INT;
        reason := IFF(similarity < 0.4, 'Low measured-set similarity (<0.4); uncertain extrapolation. ',
                     IFF(similarity < 0.6, 'Moderate measured-set similarity (0.4-0.6). ',
                         'High measured-set similarity (>=0.6). ')) ||
                  IFF(properties:ro5_pass::BOOLEAN, 'Passes Rule of Five.',
                      'Has multiple Rule-of-Five violations.');
        results := ARRAY_APPEND(:results, OBJECT_CONSTRUCT(
          'smiles', :entry, 'predicted_pic50', predicted:pic50,
          'predicted_class', predicted:activity,
          'q05', predicted:q05, 'q95', predicted:q95,
          'max_tanimoto', :similarity,
          'nearest_measured', nearest:neighbours[0],
          'ro5', :properties, 'triage_score', ROUND(:ranking, 3),
          'reason', :reason));
      END IF;
    END IF;
  END FOR;
  SELECT COALESCE(ARRAY_AGG(value) WITHIN GROUP (ORDER BY value:triage_score::FLOAT DESC NULLS LAST), ARRAY_CONSTRUCT())
    INTO :results FROM TABLE(FLATTEN(INPUT => :results));
  RETURN OBJECT_CONSTRUCT('ranked_compounds', :results,
    'note', 'Similarity uses all 2751 measured compounds including held-out rows. Prioritization heuristic, not a clinical decision or calibrated applicability domain. Ranges are uncalibrated model quantiles.');
END;
$$;

-- Create the agent from agent/aromatase_agent.yaml after the SQL above with
-- scripts/deploy_agent.py. The script also lists it in Snowflake Intelligence.
