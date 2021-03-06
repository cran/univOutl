HBmethod <- function(yt1, yt2, U=0.5, A=0.05, C=4, pct=0.25, 
                    id=NULL, std.score=FALSE, return.dataframe=FALSE, adjboxE=FALSE)
{

    # check input vectors
    if(length(yt1) != length(yt2)) stop('Input vectors have different lengths')
    if(is.null(id)) id <- 1:length(yt1)
                        
    # discard 0s and NAs
    tst.na <- is.na(yt1) | is.na(yt2)
    tst.0 <- (yt1==0) | (yt2==0)
    tst <- tst.0 | tst.na
    
    if(sum(tst)==0){
        discard <- integer(0)
        yy1 <- yt1
        yy2 <- yt2
        lab <- id
    }
    else{
        discard <- id[tst]
        yy1 <- yt1[!tst]
        yy2 <- yt2[!tst]
        lab <- id[!tst]
    }
                        
    # derive Hidiroglou-Berthelot score

    rr <- yy2/yy1
    mdn.rr <- median(rr)

    sc <- ifelse((rr < mdn.rr), (1 - mdn.rr/rr), (rr/mdn.rr - 1))
    sizeU <- (pmax(yy1, yy2)) ^ U
    E <- sc * sizeU
    
    # compute bounds for scores
    # q.E <- quantile(x = E, probs = c(0.25, 0.50, 0.75))
    q.E <- quantile(x = E, probs = c(pct, 0.50, (1-pct)))
    
    if(all(abs(q.E)<1e-06)) stop("Quartiles of E scores are all equal to 0")
    
    message('MedCouple skewness measure of E scores: ', round(robustbase::mc(E), 4))
    
    dq1 <- max( (q.E[2] - q.E[1]), abs(A * q.E[2]) )
    dq3 <- max( (q.E[3] - q.E[2]), abs(A * q.E[2]) )

    if(std.score){
        ncost <- qnorm(1-pct)
        std.Escore <- (E - q.E[2])/dq1*(1/ncost)
        std.Escore[E >= q.E[2]] <- c((E - q.E[2])/dq3*(1/ncost))[E >= q.E[2]]
    }

    # identifies outliers

    if(length(C)==1) C <- rep(C, 2)
    low.b <- q.E[2] - C[1] * dq1
    up.b <- q.E[2] + C[2] * dq3        

    names(low.b) <- 'low'
    names(up.b) <- 'up'
    
    outl <- (E < low.b) | (E > up.b)
    if(sum(outl)==0) message('No outliers found')
    else{
        message('Outliers found in the left tail: ', sum(E < low.b))
        message('Outliers found in the right tail: ', sum(E > up.b))
    }
    fine0 <- list(median.r = mdn.rr, quartiles.E=q.E, bounds.E=c(low.b, up.b))
    
    # if adjboxE=TRUE identifies outliers also with skew-adj boxplot on E-scores
    if(adjboxE){
        out.bb <- boxB(x = E, k = 1.5, method = "adjbox")
        message('Outliers found in the left tail with adj. boxplot on E: ', sum(E < out.bb$fences[1]))
        message('Outliers found in the rights tail with adj. boxplot on E: ', sum(E > out.bb$fences[2]))
        
        outlBB <- rep(0, length(outl))
        if(length(out.bb$outliers)>0) outlBB[out.bb$outliers] <- 1
        fine0$fences.E.BB <- out.bb$fences     
    }
    
    # output
    
    if(return.dataframe){
        discard <- data.frame(id=id[tst],
                              yt1=yt1[tst],
                              yt2=yt2[tst])

        df.outl <- data.frame(id=id[!tst],
                              yt1=yt1[!tst],
                              yt2=yt2[!tst],
                              ratio=rr, sizeU=sizeU, Escore=E)
        if(std.score) df.outl$std.Escore <- std.Escore
        df.outl$outliers <- as.integer(outl)
        
        if(adjboxE) df.outl$outliersBB <- outlBB
        fine1 <- list(excluded=discard, data = df.outl)
    }
    else{
        if(sum(outl)==0) fine1 <- list(excluded=discard, outliers = integer(0))   
        else fine1 <- list(excluded=discard, outliers = lab[outl])
        
        if(adjboxE) {
            if(sum(outlBB)==0) fine1$outliersBB <- integer(0)
            else fine1$outliersBB <- lab[outlBB==1]
        }
    }
    c(fine0, fine1, call=match.call())
}