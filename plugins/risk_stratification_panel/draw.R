draw_plot <- function(df) {
  id_col <- oc_col(df,'id_column','subject');score_col <- oc_col(df,'value_column','risk_score');time_col <- oc_col(df,'time_column','time');event_col <- oc_col(df,'event_column','event')
  d <- data.frame(subject=as.character(df[[id_col]]),score=oc_numeric(df,score_col),time=oc_numeric(df,time_col,TRUE),event=oc_numeric(df,event_col),group=oc_group(df))
  if(anyNA(d$subject)||any(!nzchar(d$subject))||anyDuplicated(d$subject))stop('Supply one row per unique subject identifier.')
  if(any(!d$event %in% c(0,1)))stop('Event coding must be 0 = censored and 1 = event.')
  order <- if(chr('sort_by','risk')=='risk')order(d$score,seq_len(nrow(d)))else seq_len(nrow(d))
  d <- d[order,];d$rank<-seq_len(nrow(d));colors<-oc_colors(d$group)
  p1<-ggplot(d,aes(rank,score,color=group))+geom_point(size=num('point_size',2),alpha=num('point_alpha',.8))+scale_color_manual(values=colors,name='Group')+labs(x=NULL,y=score_col)+oc_theme()
  p2<-ggplot(d,aes(rank,time,color=group,shape=factor(event)))+geom_point(size=num('point_size',2),alpha=num('point_alpha',.8))+scale_color_manual(values=colors,name='Group')+scale_shape_manual(values=c('0'=1,'1'=17),labels=c('Censored','Event'),name='Follow-up')+labs(x=NULL,y=time_col)+oc_theme()
  feature_columns<-chr_vec('feature_columns');heat<-NULL
  panels<-list(p1,p2);heights<-c(1,1)
  if(flag('heatmap_show',TRUE)&&length(feature_columns)) {
    if(length(setdiff(feature_columns,names(df))))stop('Some feature_columns are not present in the input.')
    heat<-do.call(rbind,lapply(feature_columns,function(feature){
      values<-oc_numeric(df,feature)[order]
      if(flag('scale_features',TRUE)) {
        spread<-sd(values);if(!is.finite(spread)||spread==0)spread<-1
        values<-(values-mean(values))/spread
      }
      data.frame(rank=d$rank,subject=d$subject,feature=feature,value=values)
    }))
    heat$feature<-factor(heat$feature,levels=rev(feature_columns))
    panels[[3]]<-ggplot(heat,aes(rank,feature,fill=value))+geom_tile(width=1,height=.95)+scale_fill_gradient2(low=chr('low_color','#397DA3'),mid='#F5F6F7',high=chr('high_color','#D16472'),midpoint=0,name=if(flag('scale_features',TRUE))'Feature Z-score'else'Feature value')+labs(x='Subject order',y=NULL)+oc_theme()+theme(axis.line.y=element_blank(),axis.ticks.y=element_blank())
    heights<-c(1,1,max(.9,length(feature_columns)*.18))
  }
  for(i in seq_along(panels)) {
    panels[[i]]<-panels[[i]]+scale_x_continuous(limits=c(.5,nrow(d)+.5),expand=c(0,0),breaks=if(flag('subject_label_show',FALSE))d$rank else pretty(d$rank),labels=if(flag('subject_label_show',FALSE))d$subject else waiver())
    if(i<length(panels))panels[[i]]<-panels[[i]]+theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.title.x=element_blank())else if(flag('subject_label_show',FALSE))panels[[i]]<-panels[[i]]+theme(axis.text.x=element_text(angle=90,hjust=1,size=7))
  }
  p<-patchwork::wrap_plots(panels,ncol=1,heights=heights,guides='collect')
  oc_result(p,d,list(method='supplied_risk_rank_panel',sort_by=chr('sort_by','risk'),feature_scaling=if(flag('scale_features',TRUE))'per-feature Z-score across subjects'else'none'),if(!is.null(heat))list('features_used.csv'=heat)else list(),'Supplied scores, follow-up and features; no risk model fitted and no optimal cutoff selected')
}
