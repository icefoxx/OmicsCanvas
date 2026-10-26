# Classification report

Counts: demo=99, export=2, legacy_alias=21, parameter=24, preset=2, rendering=1, variant=141

| plugin | example | class | maps_to | notes |
|---|---|---|---|---|
| `advanced_dim_plot` | `pdf_repro_basic_umap` | demo | clusters/recommended | Basic UMAP (clusters) |
| `advanced_dim_plot` | `pdf_repro_ellipse_mark` | demo | ellipse/recommended | Ellipse marks |
| `advanced_dim_plot` | `pdf_repro_split_samples` | demo | split_samples/recommended | Split by sample |
| `advanced_dim_plot` | `pdf_repro_composition_ring` | demo | composition/recommended | Composition rings |
| `advanced_dim_plot` | `pdf_repro_highlight_cells` | demo | highlight_cells/recommended | Highlight cells |
| `advanced_dim_plot` | `pdf_repro_bg_cutoff_mito` | demo | background_mask/recommended | Background by mito cutoff |
| `advanced_dim_plot` | `pdf_repro_bg_condition` | demo | background_mask/recommended | Background by samples |
| `advanced_dim_plot` | `axis_label_controls` | parameter | clusters/recommended | axis_label_controls |
| `advanced_dim_plot` | `background_mask` | legacy_alias | background_mask/recommended | background_mask |
| `advanced_dim_plot` | `basic_umap` | legacy_alias | clusters/recommended | basic_umap |
| `advanced_dim_plot` | `bg_condition` | legacy_alias | background_mask/recommended | bg_condition |
| `advanced_dim_plot` | `bg_cutoff` | legacy_alias | background_mask/recommended | bg_cutoff |
| `advanced_dim_plot` | `blank_theme` | preset | clusters/blank | blank_theme |
| `advanced_dim_plot` | `cluster_composition_ring` | legacy_alias | composition/recommended | cluster_composition_ring |
| `advanced_dim_plot` | `coexpression` | demo | coexpression/recommended | coexpression |
| `advanced_dim_plot` | `coexpression_screen` | legacy_alias | coexpression/recommended | coexpression_screen |
| `advanced_dim_plot` | `density_filled` | legacy_alias | density/recommended | density_filled |
| `advanced_dim_plot` | `density_hex` | legacy_alias | density/recommended | density_hex |
| `advanced_dim_plot` | `ellipse_mark` | legacy_alias | ellipse/recommended | ellipse_mark |
| `advanced_dim_plot` | `embedded_pie` | legacy_alias | composition/recommended | embedded_pie |
| `advanced_dim_plot` | `feature` | demo | feature_expression/recommended | feature |
| `advanced_dim_plot` | `group` | legacy_alias | clusters/recommended | group |
| `advanced_dim_plot` | `highlight_cells` | legacy_alias | highlight_cells/recommended | highlight_cells |
| `advanced_dim_plot` | `highlight_ring` | legacy_alias | highlight_cells/recommended | highlight_ring |
| `advanced_dim_plot` | `lineage` | demo | lineage/recommended | lineage |
| `advanced_dim_plot` | `mark_shapes` | parameter | ellipse/recommended | mark_shapes |
| `advanced_dim_plot` | `pdf_basic_umap` | export | clusters/publication | pdf_basic_umap |
| `advanced_dim_plot` | `pdf_ellipse_mark` | export | ellipse/publication | pdf_ellipse_mark |
| `advanced_dim_plot` | `raster` | rendering | clusters/large_dataset | raster |
| `advanced_dim_plot` | `split_highlight` | variant | split_highlight/recommended | split_highlight |
| `advanced_dim_plot` | `split_samples` | legacy_alias | split_samples/recommended | split_samples |
| `advanced_dim_plot` | `stat_panel` | demo | stat_panel/recommended | stat_panel |
| `advanced_feature_plot` | `pdf_repro_basic_two_features` | demo | feature_expression/recommended | Basic · Atoh1 + Neurod1 |
| `advanced_feature_plot` | `pdf_repro_multi_feature_scaled` | demo | feature_expression/recommended | Multi · 4 genes scaled |
| `advanced_feature_plot` | `pdf_repro_split_by_sample` | demo | split_feature_expression/recommended | Split by sample |
| `advanced_feature_plot` | `pdf_repro_feature_comp_multiply` | demo | feature_coexpression/recommended | Composite multiply |
| `advanced_feature_plot` | `pdf_repro_highlight_cells` | demo | feature_expression/recommended | Highlight cells |
| `advanced_feature_plot` | `pdf_repro_split_global_blank` | preset | split_feature_expression/blank | Split · shared coords |
| `advanced_feature_plot` | `pdf_repro_hexbin` | demo | aggregated_feature_expression/recommended | Hexbin features |
| `advanced_feature_plot` | `density_hex` | legacy_alias | aggregated_feature_expression/recommended | density_hex |
| `advanced_feature_plot` | `feature_comp` | legacy_alias | feature_coexpression/recommended | feature_comp |
| `advanced_feature_plot` | `highlight_blank` | legacy_alias | feature_expression/blank | highlight_blank |
| `advanced_feature_plot` | `multi_feature` | legacy_alias | feature_expression/recommended | multi_feature |
| `advanced_feature_plot` | `single_feature` | legacy_alias | feature_expression/recommended | single_feature |
| `advanced_feature_plot` | `split_feature` | legacy_alias | split_feature_expression/recommended | split_feature |
| `alluvial_plot` | `basic` | demo | basic/recommended | basic |
| `alluvial_plot` | `edges` | variant | edges/recommended | edges |
| `alluvial_plot` | `hx_lineage` | variant | hx_lineage/recommended | hx_lineage |
| `alluvial_plot` | `long` | variant | long/recommended | long |
| `annotated_tree_plot` | `basic` | demo | basic/recommended | Supplied tree and feature heatmap |
| `annotated_tree_plot` | `circular` | variant | circular/recommended | Circular tree with weighted nodes |
| `balloon_plot` | `basic` | demo | basic/recommended | basic |
| `balloon_plot` | `gradient` | variant | gradient/recommended | gradient |
| `balloon_plot` | `no_stats` | variant | no_stats/recommended | no_stats |
| `bar3d_plot` | `basic` | demo | basic/recommended | Mutation-context count grid |
| `bar3d_plot` | `free_scale` | variant | free_scale/recommended | Grid heights with independent panel scales |
| `binary_evaluation_plot` | `basic` | demo | basic/recommended | Receiver operating characteristic |
| `binary_evaluation_plot` | `precision_recall` | variant | precision_recall/recommended | Precision and recall |
| `binary_evaluation_plot` | `calibration` | variant | calibration/recommended | Probability calibration |
| `binary_evaluation_plot` | `decision_curve` | variant | decision_curve/recommended | Net benefit by threshold |
| `binary_evaluation_plot` | `supplied_curve` | variant | supplied_curve/recommended | Supplied evaluation curves |
| `bland_altman_plot` | `basic` | demo | basic/recommended | Paired measurement agreement |
| `bland_altman_plot` | `percent` | variant | percent/recommended | Relative measurement agreement |
| `circular_bar_plot` | `basic` | demo | basic/recommended | Basic |
| `circular_bar_plot` | `single` | variant | single/recommended | Single series |
| `circular_distribution_plot` | `basic` | demo | basic/recommended | Scores across reference groups |
| `circular_distribution_plot` | `shared_range` | variant | shared_range/recommended | Scores on a common scale |
| `circular_genomic_plot` | `basic` | demo | basic/recommended | Circular interval heatmap |
| `circular_genomic_plot` | `bars` | variant | bars/recommended | Circular interval magnitudes |
| `circular_genomic_plot` | `points` | variant | points/recommended | Circular interval points |
| `circular_genomic_plot` | `linear` | variant | linear/recommended | Linear chromosome overview |
| `circular_heatmap` | `basic` | demo | basic/recommended | Basic |
| `circular_heatmap` | `clustered` | variant | clustered/recommended | Clustered |
| `circular_heatmap` | `categorical` | variant | categorical/recommended | Categorical annotation rings |
| `circular_tree_embedding` | `basic` | demo | basic/recommended | Annotation hierarchy |
| `circular_tree_embedding` | `similarity` | variant | similarity/recommended | Feature similarity |
| `circular_tree_embedding` | `CAB_demo` | variant | cab_demo/recommended | CAB_demo |
| `classified_bar_plot` | `CAB_demo` | variant | cab_demo/recommended | Horizontal classified bars |
| `classified_bar_plot` | `vertical` | variant | vertical/recommended | Vertical classified bars |
| `classified_bar_plot` | `basic` | demo | basic/recommended | Basic classified bars |
| `classified_bar_plot` | `labeled` | parameter | labels | Labeled classified bars |
| `clonal_fish_plot` | `basic` | demo | basic/recommended | Nested clone fractions |
| `clonal_fish_plot` | `percent` | variant | percent/recommended | Clone fractions in percent |
| `cluster_dendrogram_plot` | `basic` | demo | basic/recommended | basic |
| `cluster_dendrogram_plot` | `colored_labels` | parameter | labels | colored_labels |
| `cluster_dendrogram_plot` | `subset` | variant | subset/recommended | subset |
| `combo_bar_dot_matrix` | `bar_only` | variant | bar_only/recommended | bar_only |
| `combo_bar_dot_matrix` | `basic` | demo | basic/recommended | basic |
| `combo_bar_dot_matrix` | `heatmap_dots` | variant | heatmap_dots/recommended | heatmap_dots |
| `combo_bar_line_plot` | `basic` | demo | basic/recommended | basic |
| `combo_bar_line_plot` | `CAB_demo` | variant | cab_demo/recommended | CAB_demo |
| `combo_bar_line_plot` | `labeled` | parameter | labels | labeled |
| `combo_bar_line_plot` | `long` | variant | long/recommended | long |
| `den_plot` | `basic` | demo | basic/recommended | basic |
| `den_plot` | `colored_labels` | parameter | labels | colored_labels |
| `den_plot` | `subset` | variant | subset/recommended | subset |
| `dot_plot` | `aggregate` | demo | marker_dot/recommended | From expression matrix |
| `dot_plot` | `basic` | demo | marker_dot/recommended | Marker expression by cluster |
| `dot_plot` | `dendro` | legacy_alias | marker_dot/recommended | With gene and cluster dendrograms |
| `dynamic_venn_diagram` | `abundance` | variant | abundance/recommended | abundance |
| `dynamic_venn_diagram` | `params` | demo | params/recommended | params |
| `ecdf_plot` | `basic` | demo | basic/recommended | Cumulative score distributions |
| `ecdf_plot` | `steps` | variant | steps/recommended | Empirical distribution steps |
| `embedding_vector_plot` | `basic` | demo | basic/recommended | Supplied vector field |
| `embedding_vector_plot` | `radial` | variant | radial/recommended | Supplied outward displacement field |
| `exp_stat_plot` | `bar` | demo | grouped_bar/recommended | bar |
| `exp_stat_plot` | `box_split` | parameter | marks | box_split |
| `exp_stat_plot` | `col_flip` | demo | flipped_bar/recommended | col_flip |
| `exp_stat_plot` | `custom_style` | parameter | theme | custom_style |
| `exp_stat_plot` | `dot_stack` | parameter | marks | dot_stack |
| `exp_stat_plot` | `highlight` | parameter | marks | highlight |
| `exp_stat_plot` | `violin` | parameter | marks | violin |
| `feature_density_plot` | `basic` | demo | basic/recommended | basic |
| `feature_density_plot` | `coexpression` | variant | coexpression/recommended | coexpression |
| `feature_density_plot` | `scale01` | variant | scale01/recommended | scale01 |
| `fgsea_enrichment_plot` | `custom_layout` | parameter | layout | custom_layout |
| `fgsea_enrichment_plot` | `dot_summary` | variant | dot_summary/recommended | dot_summary |
| `fgsea_enrichment_plot` | `gradient_curve` | variant | running/recommended | gradient_curve |
| `fgsea_enrichment_plot` | `image_like` | variant | running/publication | Gradient multi-term GSEA |
| `fgsea_enrichment_plot` | `multiterm` | variant | running/recommended | Annotated multi-term GSEA |
| `fgsea_enrichment_plot` | `running` | variant | running/recommended | Faceted term-panel GSEA |
| `fgsea_enrichment_plot` | `multigroup` | variant | multi_group/recommended | Multi-group GSEA overlay |
| `fgsea_enrichment_plot` | `summary` | variant | summary/recommended | summary |
| `fgsea_enrichment_plot` | `ridge` | variant | ridge/recommended | Enrichment ridge (log2FC density) |
| `fgsea_enrichment_plot` | `gene_sankey` | variant | gene_sankey/recommended | Gene-pathway Sankey + bubble |
| `forest_plot` | `basic` | demo | basic/recommended | Effect estimates and confidence intervals |
| `forest_plot` | `log_ratio` | variant | log_ratio/recommended | Ratios on a logarithmic axis |
| `forest_plot` | `signed_effects` | variant | signed_effects/recommended | Signed differences |
| `go_kegg_enrichment_bar_bubble` | `go_kegg` | demo | grouped_bar_dot/recommended | GO / KEGG Bar + Count Dots |
| `group_heatmap` | `cell_heatmap` | demo | cell_heatmap/recommended | cell_heatmap |
| `group_heatmap` | `clustered_dotplot` | demo | clustered_dotplot/recommended | clustered_dotplot |
| `group_heatmap` | `dotplot` | demo | dotplot/recommended | dotplot |
| `group_heatmap` | `heatmap` | demo | heatmap/recommended | heatmap |
| `group_heatmap` | `violin` | parameter | marks | violin |
| `gsea_pathway_heatmap` | `basic` | demo | basic/recommended | basic |
| `gsea_pathway_heatmap` | `precomputed` | variant | precomputed/recommended | precomputed |
| `gsea_pathway_heatmap` | `with_annotation` | variant | with_annotation/recommended | with_annotation |
| `gsea_ridge_nes_plot` | `basic` | demo | basic/recommended | Pathway Ridge + NES |
| `hierarchical_marker_panel` | `basic` | demo | basic/recommended | Basic hierarchical marker panel |
| `hierarchical_marker_panel` | `CAB_demo` | variant | cab_demo/recommended | CAB_demo |
| `hierarchical_marker_panel` | `sample_percent` | variant | sample_percent/recommended | Sample composition percent |
| `hierarchical_marker_panel` | `stress_3x5` | variant | stress_3x5/recommended | Layout stress: 3 cell types x 5 markers |
| `hierarchical_marker_panel` | `stress_10x20` | variant | stress_10x20/recommended | Layout stress: 10 cell types x 20 markers |
| `hierarchical_marker_panel` | `stress_30x50` | variant | stress_30x50/recommended | Layout stress: 30 cell types x 50 markers |
| `hierarchical_marker_panel` | `summary_bar` | variant | summary_bar/recommended | Summary: standard bar |
| `hierarchical_marker_panel` | `summary_stacked` | variant | summary_stacked/recommended | Summary: stacked bar |
| `hierarchical_marker_panel` | `summary_grouped` | variant | summary_grouped/recommended | Summary: grouped bar |
| `hierarchical_marker_panel` | `summary_pie` | variant | summary_pie/recommended | Summary: pie per cluster |
| `hierarchical_marker_panel` | `summary_donut` | variant | summary_donut/recommended | Summary: donut per cluster |
| `highlight_effect_plot` | `basic` | demo | basic/recommended | basic |
| `highlight_effect_plot` | `no_collapse` | variant | no_collapse/recommended | no_collapse |
| `highlight_effect_plot` | `summary` | variant | summary/recommended | summary |
| `interactive_3d_scatter` | `basic` | demo | basic/recommended | Three-dimensional sample coordinates |
| `interactive_3d_scatter` | `alternate_view` | variant | alternate_view/recommended | Alternate viewing angle |
| `interactive_arc_network_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_arc_network_plot` | `custom` | variant | custom/recommended | custom |
| `interactive_arc_network_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_binary_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_binary_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_binary_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_bubble_score_matrix` | `basic` | demo | basic/recommended | basic |
| `interactive_bubble_score_matrix` | `custom` | variant | custom/recommended | custom |
| `interactive_bubble_score_matrix` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_bubble_score_matrix` | `multi_score` | variant | multi_score/recommended | multi_score |
| `interactive_clustered_heatmap_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_clustered_heatmap_plot` | `custom` | variant | custom/recommended | custom |
| `interactive_clustered_heatmap_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_clustered_heatmap_plot` | `panels` | variant | panels/recommended | panels |
| `interactive_correlation_matrix` | `basic` | demo | basic/recommended | basic |
| `interactive_correlation_matrix` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_correlation_matrix` | `lower_triangle` | variant | lower_triangle/recommended | lower_triangle |
| `interactive_dual_triangle_heatmap_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_dual_triangle_heatmap_plot` | `custom` | variant | custom/recommended | custom |
| `interactive_dual_triangle_heatmap_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_dumbbell_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_dumbbell_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_dumbbell_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_enrichment_lollipop` | `basic` | demo | lollipop/recommended | basic |
| `interactive_enrichment_lollipop` | `oct4_enrichment` | demo | oct4_enrichment/recommended | OCT4 enrichment |
| `interactive_enrichment_lollipop` | `CAB_demo` | demo | diverging_tf/recommended | Diverging transcription factor lollipop |
| `interactive_genomic_signal_track_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_genomic_signal_track_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_genomic_signal_track_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_histogram_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_histogram_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_histogram_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_mantel_correlation_network` | `basic` | demo | mantel_pearson/recommended | basic |
| `interactive_motif_logo_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_motif_logo_plot` | `custom` | variant | custom/recommended | custom |
| `interactive_motif_logo_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_network_plot` | `network` | variant | network/recommended | Force-directed network |
| `interactive_network_plot` | `circle` | variant | circle/recommended | Circular layout |
| `interactive_network_plot` | `concentric` | variant | concentric/recommended | Concentric layout |
| `interactive_network_plot` | `membership` | variant | membership/recommended | Membership radial |
| `interactive_network_plot` | `manual_layout` | parameter | network/recommended | Manual layout |
| `interactive_pie_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_pie_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_pie_plot` | `donut` | variant | donut/recommended | donut |
| `interactive_radar_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_radar_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_radar_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_ridgeline_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_ridgeline_plot` | `CAB_demo` | variant | cab_demo/recommended | CAB_demo |
| `interactive_ridgeline_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_ridgeline_plot` | `grouped` | variant | grouped/recommended | grouped |
| `interactive_ridgeline_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_sankey_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_sankey_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_sankey_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_upset_plot` | `all_intersections` | variant | all_intersections/recommended | all_intersections |
| `interactive_upset_plot` | `annotated_categorical` | variant | annotated_categorical/recommended | annotated_categorical |
| `interactive_upset_plot` | `annotated_numeric` | variant | annotated_numeric/recommended | annotated_numeric |
| `interactive_upset_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_upset_plot` | `grouped` | variant | grouped/recommended | grouped |
| `interactive_upset_plot` | `intersection_size` | variant | intersection_size/recommended | intersection_size |
| `interactive_upset_plot` | `query_highlight` | variant | query_highlight/recommended | query_highlight |
| `interactive_upset_plot` | `ratio` | variant | ratio/recommended | ratio |
| `interactive_violin_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_violin_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_violin_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_violin_plot` | `long` | variant | long/recommended | long |
| `line_plot` | `basic` | demo | basic/recommended | Basic |
| `line_plot` | `smooth` | variant | smooth/recommended | Smooth |
| `line_plot` | `interval_band` | variant | interval_band/recommended | Supplied confidence or credible bounds |
| `lineage_plot` | `basic` | demo | basic/recommended | basic |
| `lineage_plot` | `single` | variant | single/recommended | single |
| `lineage_plot` | `whiskers` | variant | whiskers/recommended | whiskers |
| `linked_matrix_network_plot` | `basic` | demo | basic/recommended | Linked matrix and relationships |
| `linked_matrix_network_plot` | `dot_matrix` | variant | dot_matrix/recommended | Dot matrix and relationships |
| `manhattan_qq_plot` | `basic` | demo | basic/recommended | Association overview |
| `manhattan_qq_plot` | `manhattan` | variant | manhattan/recommended | Genomic association signals |
| `manhattan_qq_plot` | `qq` | variant | qq/recommended | Expected and observed probabilities |
| `nomogram_plot` | `basic` | demo | basic/recommended | Supplied predictor point scales |
| `nomogram_plot` | `compact` | variant | compact/recommended | Supplied total-point outcome mapping |
| `oncoprint_plot` | `basic` | demo | basic/recommended | Multi-hit alteration matrix |
| `oncoprint_plot` | `input_order` | variant | input_order/recommended | Input-order alteration matrix |
| `pie_dot_matrix` | `basic` | demo | basic/recommended | basic |
| `pie_dot_matrix` | `binary` | variant | binary/recommended | binary |
| `pie_dot_matrix` | `correlation` | variant | correlation/recommended | correlation |
| `protein_variant_plot` | `basic` | demo | basic/recommended | Protein variants and domains |
| `protein_variant_plot` | `variants_only` | variant | variants_only/recommended | Variant count profile |
| `quadrant_correlation_scatter` | `params` | demo | params/recommended | params |
| `radviz_plot` | `basic` | demo | basic/recommended | Feature-weight wheel |
| `radviz_plot` | `minmax` | variant | minmax/recommended | Feature-scaled wheel |
| `raincloud_plot` | `basic` | demo | basic/recommended | Basic |
| `raincloud_plot` | `vertical` | variant | vertical/recommended | Vertical |
| `ranked_annotation_panel` | `params` | demo | params/recommended | params |
| `regression_scatter_plot` | `basic` | demo | basic/recommended | basic |
| `regression_scatter_plot` | `CAB_demo` | variant | cab_demo/recommended | CAB_demo |
| `risk_stratification_panel` | `basic` | demo | basic/recommended | Aligned risk and follow-up |
| `risk_stratification_panel` | `scores_only` | variant | scores_only/recommended | Scores and follow-up |
| `sca_volcano_plot` | `avg` | variant | avg/recommended | avg |
| `sca_volcano_plot` | `basic` | demo | basic/recommended | basic |
| `sca_volcano_plot` | `percent` | variant | percent/recommended | percent |
| `sca_volcano_plot` | `regions` | variant | regions/recommended | regions |
| `sequence_alignment_plot` | `basic` | demo | basic/recommended | Aligned nucleotide sequences |
| `sequence_alignment_plot` | `protein` | variant | protein/recommended | Aligned protein sequences |
| `spatial_region_plot` | `basic` | demo | basic/recommended | Measured tissue regions |
| `spatial_region_plot` | `tissue` | variant | tissue/recommended | Regions over a synthetic tissue background |
| `spatial_region_plot` | `spots` | variant | spots/recommended | Measured spatial spots |
| `stacked_bar_plot` | `basic` | demo | basic/recommended | basic |
| `stacked_bar_plot` | `CAB_demo` | variant | cab_demo/recommended | CAB_demo |
| `stacked_bar_plot` | `long` | variant | long/recommended | long |
| `stacked_bar_plot` | `normal` | variant | normal/recommended | normal |
| `stacked_bar_plot` | `percent` | variant | percent/recommended | percent |
| `stacked_bar_plot` | `vertical_labels` | parameter | labels | vertical_labels |
| `stat_plot` | `bar` | variant | bar/recommended | bar |
| `stat_plot` | `chord` | variant | chord/recommended | chord |
| `stat_plot` | `dot` | variant | dot/recommended | dot |
| `stat_plot` | `pie` | variant | pie/recommended | pie |
| `stat_plot` | `rose` | variant | rose/recommended | rose |
| `stat_plot` | `sankey` | variant | sankey/recommended | sankey |
| `stat_plot` | `upset` | variant | upset/recommended | upset |
| `stat_plot` | `venn` | variant | venn/recommended | venn |
| `sunburst_plot` | `basic` | demo | basic/recommended | Basic |
| `sunburst_plot` | `three_level` | variant | three_level/recommended | Three rings |
| `survival_plot` | `basic` | demo | basic/recommended | Survival by cohort |
| `survival_plot` | `conditional` | variant | conditional/recommended | Conditional survival |
| `survival_plot` | `event_probability` | variant | event_probability/recommended | Event probability |
| `swimmer_plot` | `basic` | demo | basic/recommended | Observation intervals and events |
| `swimmer_plot` | `staggered` | variant | staggered/recommended | Staggered observation windows |
| `ternary_plot` | `basic` | demo | basic/recommended | Basic |
| `threshold_matrix_heatmap` | `params` | demo | params/recommended | params |
| `treemap_plot` | `basic` | demo | basic/recommended | Basic |
| `violin_plot` | `anno` | variant | anno/recommended | anno |
| `violin_plot` | `basic` | demo | basic/recommended | basic |
| `violin_plot` | `dot` | variant | dot/recommended | dot |
| `violin_plot` | `matrix` | variant | matrix/recommended | matrix |
| `waterfall_plot` | `basic` | demo | basic/recommended | Basic |
| `waterfall_plot` | `no_total` | variant | no_total/recommended | Without total |
