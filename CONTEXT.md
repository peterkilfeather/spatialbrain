# SpatialBrain

A web portal for exploring mouse midbrain gene expression from the Wade-Martins Laboratory of Molecular Neurodegeneration (Kilfeather, Khoo, et al., 2024, Cell Reports 43:113784). Covers spatial transcriptomics and TRAP assays, focused on dopaminergic neurons of the substantia nigra and ventral tegmental area, including ageing.

## Language

### Assays

**Spatial transcriptomics**:
An assay that measures gene expression in situ, preserving each cell's position within its tissue section.
_Avoid_: spatial data, spatial-seq

**TRAP**:
Translating Ribosome Affinity Purification. An assay that captures ribosome-bound (translating) mRNA from a genetically defined cell population.

**DAT-TRAP**:
TRAP performed in mice whose ribosomes are tagged in dopaminergic neurons via the dopamine transporter (DAT, Slc6a3) promoter. The source of the "TRAP" samples in this project.

**TOTAL**:
Bulk RNA from the ventral midbrain, used as the baseline for TRAP comparisons.

### Anatomy

**Dopaminergic neuron**:
A neuron that synthesises and releases dopamine; the cell population of interest throughout SpatialBrain. Identified by dopamine transporter (DAT) expression.
_Avoid_: DA neuron

**Substantia nigra (SN)**:
A ventral midbrain region; its dopaminergic neurons degenerate in Parkinson's disease.

**Ventral tegmental area (VTA)**:
A ventral midbrain region adjacent to the substantia nigra; part of the reward circuitry.

**Region**:
A cell's anatomical origin — substantia nigra or ventral tegmental area — used to compare gene expression between the two.

### Analyses

**Marker**:
A gene whose expression identifies a cell type or distinguishes regions.

**TRAP enrichment**:
The comparison of mRNA abundance between TRAP and TOTAL samples. A gene is Enriched, Depleted, or Unchanged based on its log2 fold-change and adjusted p-value.

**Alternative splicing**:
Differential transcript usage in dopaminergic neurons, assessed on transcript-level counts from TRAP samples.
_Avoid_: splicing

**Proportion of expression**:
The fraction of a gene's expression contributed by a given transcript in a sample; ranges from 0 to 1.

**Ageing**:
The comparison between young (3–6 month) and old (18–22 month) mice: age-related differential expression in TRAP samples and cell number changes in the spatial data.
_Avoid_: aging

**Cell type numbers**:
The number of cells of each annotated cell type, plotted against age.

**Analysis table**:
One of the five downloadable result tables on the Download Data tab: TRAP Enrichment, Ageing, Alternative Splicing, SN/VTA Markers, or Cell Type Markers (the latter as 32 per-cell-type tables).

### Measures

**LFC**:
Log2 fold-change in abundance between two sample groups. The baseline depends on the analysis: TRAP vs TOTAL for enrichment, SN vs VTA for SN/VTA Markers, OLD vs YOUNG for ageing.

**FDR-P**:
P value adjusted for multiple comparisons using the Benjamini–Hochberg method.
