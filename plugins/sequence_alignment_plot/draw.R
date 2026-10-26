draw_plot <- function(df) {
    id_col <- oc_col(df, "id_column", "sequence_id")
    sequence_col <- oc_col(df, "sequence_column", "sequence")
    ids <- as.character(df[[id_col]])
    sequences <- toupper(gsub(" ", "", as.character(df[[sequence_col]])))
    if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids))
        stop("Sequence identifiers must be unique and nonempty.")
    if (anyNA(sequences) || length(unique(nchar(sequences))) != 1)
        stop("Sequences must already be aligned and have the same nonmissing length. Alignment is not performed here.")
    width <- nchar(sequences[1])
    if (width < 1 || width > 300 || length(ids) > 50)
        stop("Use 1\u2013300 aligned positions and at most 50 sequences; crop long alignments first.")
    alphabet <- chr("alphabet", "dna")
    allowed <- if (alphabet == "dna")
        strsplit("ACGTUNRYKMSWBDHV-.?", "")[[1]] else strsplit("ACDEFGHIKLMNPQRSTVWYBXZJUO*-.?", "")[[1]]
    residues <- strsplit(sequences, "")
    if (any(!unlist(residues) %in% allowed))
        stop("Residues outside the selected DNA/protein alphabet were found. Use dash for gaps.")
    d <- data.frame(sequence_id = rep(ids, each = width), position = rep(seq_len(width), times = length(ids)),
        residue = unlist(residues), stringsAsFactors = FALSE)
    d$row <- factor(d$sequence_id, levels = rev(ids))
    consensus <- do.call(rbind, lapply(seq_len(width), function(i) {
        values <- vapply(residues, `[`, character(1), i)
        counts <- table(values[!values %in% c("-", ".", "?")])
        data.frame(position = i, consensus = if (length(counts))
            names(counts)[which.max(counts)] else "-", fraction = if (length(counts))
            max(counts)/length(ids) else 0)
    }))
    p <- ggplot(d, aes(position, row, fill = residue)) + geom_tile(width = 0.96, height = 0.92) + scale_fill_manual(values = oc_colors(d$residue),
        name = "Residue") + scale_x_continuous(breaks = pretty(seq_len(width), n = min(10, width)), limits = c(.5, width + .5), expand = c(0, 0)) +
        oc_labels("Aligned position", "") + oc_theme() + theme(axis.line = element_blank(), axis.ticks.y = element_blank(),
        legend.key.size = grid::unit(9, "pt")) + guides(fill = guide_legend(ncol = if (alphabet == "protein")
        2 else 1))
    if (flag("residue_show", TRUE) && width <= 80)
        p <- p + geom_text(aes(label = residue), size = min(num("label_size", 2.8), 90/width), color = "#243444")
    if (flag("conservation_show", TRUE)) {
        con <- ggplot(consensus, aes(position, fraction)) + geom_col(fill = chr("conservation_color",
            "#4D7189"), width = 0.9) + scale_y_continuous(limits = c(0, 1), breaks = c(0, 1)) + scale_x_continuous(limits = c(0.5,
            width + 0.5), expand = c(0, 0)) + labs(x = NULL, y = "Consensus") + oc_theme() + theme(axis.text.x = element_blank(),
            axis.title.x = element_blank(), axis.line = element_blank(), legend.position = "none")
        p <- patchwork::wrap_plots(con, p, ncol = 1, heights = c(1, max(2, length(ids) * 0.5)))
    }
    oc_result(p, d, list(method = "supplied_alignment", alphabet = alphabet, conservation = "maximum nongap residue count divided by sequence count; ties use alphabetical first"),
        list(consensus_used.csv = consensus), "Pre-aligned sequences; no sequence alignment or phylogeny inferred")
}
