# ----------------------------------------------------
# --------	SQL Server 2016 Developer's Guide --------
# -----       Chapter 03 - SQL Server Tools      -----
# ----------------------------------------------------

# ----------------------------------------------------
# -- Section 2: Tools for Developing R Code
# ----------------------------------------------------

# Analyze the built-in iris dataset
data(iris);
plot(iris);


# Custom function for skewness and kurtosis

skewkurt <- function(p) {
    avg <- mean(p)
    cnt <- length(p)
    stdev <- sd(p)
    skew <- sum((p-avg)^3/stdev^3)/cnt
    kurt <- sum((p-avg)^4/stdev^4)/cnt-3
    return(c(skewness=skew, kurtosis=kurt))
}


# Call
skewkurt(iris$Sepal.Length);

# Clean up the workspace
rm(skewkurt);
rm(iris);
