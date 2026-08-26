# Classification report

Counts: demo=50, export_template=3, parameter=24, preset=2, variant=127

| plugin | example | class | maps_to | notes |
|---|---|---|---|---|
| `advanced_dim_plot` | `pdf_repro_basic_umap` | demo | clusters/recommended | Basic UMAP (clusters) |
| `advanced_dim_plot` | `pdf_repro_ellipse_mark` | demo | ellipse/recommended | Ellipse marks |
| `advanced_dim_plot` | `pdf_repro_split_samples` | demo | split_samples/recommended | Split by sample |
| `advanced_dim_plot` | `pdf_repro_composition_ring` | demo | composition_ring/recommended | Composition rings |
| `advanced_dim_plot` | `pdf_repro_highlight_cells` | demo | highlight_cells/recommended | Highlight cells |
| `advanced_dim_plot` | `pdf_repro_bg_cutoff_mito` | parameter | background | Background by mito cutoff |
| `advanced_dim_plot` | `pdf_repro_bg_condition` | parameter | background | Background by samples |
| `advanced_dim_plot` | `axis_label_controls` | parameter | axes | axis_label_controls |
| `advanced_dim_plot` | `background_mask` | parameter | background | background_mask |
| `advanced_dim_plot` | `basic_umap` | variant | clusters/recommended | basic_umap |
| `advanced_dim_plot` | `bg_condition` | parameter | background | bg_condition |
| `advanced_dim_plot` | `bg_cutoff` | parameter | background | bg_cutoff |
| `advanced_dim_plot` | `blank_theme` | preset | clusters/minimal | blank_theme |
| `advanced_dim_plot` | `cluster_composition_ring` | variant | composition_ring/recommended | cluster_composition_ring |
| `advanced_dim_plot` | `coexpression` | variant | coexpression/recommended | coexpression |
| `advanced_dim_plot` | `coexpression_screen` | variant | coexpression/recommended | coexpression_screen |
| `advanced_dim_plot` | `density_filled` | variant | density/recommended | density_filled |
| `advanced_dim_plot` | `density_hex` | variant | density/recommended | density_hex |
| `advanced_dim_plot` | `ellipse_mark` | variant | ellipse/recommended | ellipse_mark |
| `advanced_dim_plot` | `embedded_pie` | variant | composition_pie/recommended | embedded_pie |
| `advanced_dim_plot` | `feature` | variant | feature_expression/recommended | feature |
| `advanced_dim_plot` | `group` | variant | clusters/recommended | group |
| `advanced_dim_plot` | `highlight_cells` | variant | highlight_cells/recommended | highlight_cells |
| `advanced_dim_plot` | `highlight_ring` | variant | highlight_cells/recommended | highlight_ring |
| `advanced_dim_plot` | `lineage` | variant | lineage/recommended | lineage |
| `advanced_dim_plot` | `mark_shapes` | variant | mark_shapes/recommended | mark_shapes |
| `advanced_dim_plot` | `pdf_basic_umap` | export_template | clusters/publication | pdf_basic_umap |
| `advanced_dim_plot` | `pdf_ellipse_mark` | export_template | ellipse/publication | pdf_ellipse_mark |
| `advanced_dim_plot` | `raster` | export_template | clusters/large_dataset | raster |
| `advanced_dim_plot` | `split_highlight` | variant | highlight_cells/recommended | split_highlight |
| `advanced_dim_plot` | `split_samples` | variant | split_samples/recommended | split_samples |
| `advanced_dim_plot` | `stat_panel` | variant | stat_panel/recommended | stat_panel |
| `advanced_feature_plot` | `pdf_repro_basic_two_features` | demo | multi_feature/recommended | Basic · Atoh1 + Neurod1 |
| `advanced_feature_plot` | `pdf_repro_multi_feature_scaled` | demo | multi_feature/recommended | Multi · 4 genes scaled |
| `advanced_feature_plot` | `pdf_repro_split_by_sample` | demo | split_samples/recommended | Split by sample |
| `advanced_feature_plot` | `pdf_repro_feature_comp_multiply` | demo | coexpression/recommended | Composite multiply |
| `advanced_feature_plot` | `pdf_repro_highlight_cells` | demo | highlight_cells/recommended | Highlight cells |
| `advanced_feature_plot` | `pdf_repro_split_global_blank` | preset | split_samples/minimal | Split · shared coords |
| `advanced_feature_plot` | `pdf_repro_hexbin` | demo | density/recommended | Hexbin features |
| `advanced_feature_plot` | `density_hex` | variant | density/recommended | density_hex |
| `advanced_feature_plot` | `feature_comp` | variant | coexpression/recommended | feature_comp |
| `advanced_feature_plot` | `highlight_blank` | variant | highlight_cells/minimal | highlight_blank |
| `advanced_feature_plot` | `multi_feature` | variant | multi_feature/recommended | multi_feature |
| `advanced_feature_plot` | `single_feature` | variant | single_feature/recommended | single_feature |
| `advanced_feature_plot` | `split_feature` | variant | split_samples/recommended | split_feature |
| `alluvial_plot` | `basic` | demo | basic/recommended | basic |
| `alluvial_plot` | `edges` | variant | edges/recommended | edges |
| `alluvial_plot` | `hx_lineage` | variant | hx_lineage/recommended | hx_lineage |
| `alluvial_plot` | `long` | variant | long/recommended | long |
| `balloon_plot` | `basic` | demo | basic/recommended | basic |
| `balloon_plot` | `gradient` | variant | gradient/recommended | gradient |
| `balloon_plot` | `no_stats` | variant | no_stats/recommended | no_stats |
| `classified_bar_plot` | `basic` | demo | basic/recommended | basic |
| `classified_bar_plot` | `chiplot` | variant | chiplot/recommended | chiplot |
| `classified_bar_plot` | `labeled` | parameter | labels | labeled |
| `classified_bar_plot` | `vertical` | variant | vertical/recommended | vertical |
| `cluster_dendrogram_plot` | `basic` | demo | basic/recommended | basic |
| `cluster_dendrogram_plot` | `colored_labels` | parameter | labels | colored_labels |
| `cluster_dendrogram_plot` | `subset` | variant | subset/recommended | subset |
| `combo_bar_dot_matrix` | `bar_only` | variant | bar_only/recommended | bar_only |
| `combo_bar_dot_matrix` | `basic` | demo | basic/recommended | basic |
| `combo_bar_dot_matrix` | `heatmap_dots` | variant | heatmap_dots/recommended | heatmap_dots |
| `combo_bar_line_plot` | `basic` | demo | basic/recommended | basic |
| `combo_bar_line_plot` | `chiplot` | variant | chiplot/recommended | chiplot |
| `combo_bar_line_plot` | `labeled` | parameter | labels | labeled |
| `combo_bar_line_plot` | `long` | variant | long/recommended | long |
| `den_plot` | `basic` | demo | basic/recommended | basic |
| `den_plot` | `colored_labels` | parameter | labels | colored_labels |
| `den_plot` | `subset` | variant | subset/recommended | subset |
| `dot_plot` | `aggregate` | variant | aggregate/recommended | aggregate |
| `dot_plot` | `basic` | demo | basic/recommended | basic |
| `dot_plot` | `dendro` | variant | dendro/recommended | dendro |
| `dynamic_venn_diagram` | `abundance` | variant | abundance/recommended | abundance |
| `dynamic_venn_diagram` | `params` | demo | params/recommended | params |
| `exp_stat_plot` | `bar` | variant | bar/recommended | bar |
| `exp_stat_plot` | `box_split` | variant | box_split/recommended | box_split |
| `exp_stat_plot` | `col_flip` | variant | col_flip/recommended | col_flip |
| `exp_stat_plot` | `custom_style` | variant | custom_style/recommended | custom_style |
| `exp_stat_plot` | `dot_stack` | variant | dot_stack/recommended | dot_stack |
| `exp_stat_plot` | `highlight` | variant | highlight/recommended | highlight |
| `exp_stat_plot` | `violin` | variant | violin/recommended | violin |
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
| `group_heatmap` | `cell_heatmap` | variant | heatmap/recommended | cell_heatmap |
| `group_heatmap` | `clustered_dotplot` | variant | clustered_dotplot/recommended | clustered_dotplot |
| `group_heatmap` | `dotplot` | variant | dotplot/recommended | dotplot |
| `group_heatmap` | `heatmap` | variant | heatmap/recommended | heatmap |
| `group_heatmap` | `violin` | variant | violin/recommended | violin |
| `gsea_pathway_heatmap` | `basic` | demo | basic/recommended | basic |
| `gsea_pathway_heatmap` | `precomputed` | variant | precomputed/recommended | precomputed |
| `gsea_pathway_heatmap` | `with_annotation` | variant | with_annotation/recommended | with_annotation |
| `highlight_effect_plot` | `basic` | demo | basic/recommended | basic |
| `highlight_effect_plot` | `no_collapse` | variant | no_collapse/recommended | no_collapse |
| `highlight_effect_plot` | `summary` | variant | summary/recommended | summary |
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
| `interactive_enrichment_lollipop` | `basic` | demo | basic/recommended | basic |
| `interactive_enrichment_lollipop` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_enrichment_lollipop` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_enrichment_lollipop` | `oct4_enrichment` | variant | oct4_enrichment/recommended | OCT4 enrichment |
| `interactive_genomic_signal_track_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_genomic_signal_track_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_genomic_signal_track_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_histogram_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_histogram_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_histogram_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_mantel_correlation_network` | `basic` | demo | basic/recommended | basic |
| `interactive_mantel_correlation_network` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_mantel_correlation_network` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_motif_logo_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_motif_logo_plot` | `custom` | variant | custom/recommended | custom |
| `interactive_motif_logo_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_network_plot` | `manual_layout` | parameter | layout | manual_layout |
| `interactive_network_plot` | `membership` | variant | membership/recommended | membership |
| `interactive_network_plot` | `network` | variant | network/recommended | network |
| `interactive_pie_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_pie_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_pie_plot` | `donut` | variant | donut/recommended | donut |
| `interactive_radar_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_radar_plot` | `custom_layout` | parameter | layout | custom_layout |
| `interactive_radar_plot` | `interactive` | variant | interactive/recommended | interactive |
| `interactive_ridgeline_plot` | `basic` | demo | basic/recommended | basic |
| `interactive_ridgeline_plot` | `chiplot` | variant | chiplot/recommended | chiplot |
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
| `lineage_plot` | `basic` | demo | basic/recommended | basic |
| `lineage_plot` | `single` | variant | single/recommended | single |
| `lineage_plot` | `whiskers` | variant | whiskers/recommended | whiskers |
| `pie_dot_matrix` | `basic` | demo | basic/recommended | basic |
| `pie_dot_matrix` | `binary` | variant | binary/recommended | binary |
| `pie_dot_matrix` | `correlation` | variant | correlation/recommended | correlation |
| `quadrant_correlation_scatter` | `params` | demo | params/recommended | params |
| `ranked_annotation_panel` | `params` | demo | params/recommended | params |
| `regression_scatter_plot` | `basic` | demo | basic/recommended | basic |
| `regression_scatter_plot` | `chiplot` | variant | chiplot/recommended | chiplot |
| `sca_volcano_plot` | `avg` | variant | avg/recommended | avg |
| `sca_volcano_plot` | `basic` | demo | basic/recommended | basic |
| `sca_volcano_plot` | `percent` | variant | percent/recommended | percent |
| `sca_volcano_plot` | `regions` | variant | regions/recommended | regions |
| `stacked_bar_plot` | `basic` | demo | basic/recommended | basic |
| `stacked_bar_plot` | `chiplot` | variant | chiplot/recommended | chiplot |
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
| `threshold_matrix_heatmap` | `params` | demo | params/recommended | params |
| `violin_plot` | `anno` | variant | anno/recommended | anno |
| `violin_plot` | `basic` | demo | basic/recommended | basic |
| `violin_plot` | `dot` | variant | dot/recommended | dot |
| `violin_plot` | `matrix` | variant | matrix/recommended | matrix |
