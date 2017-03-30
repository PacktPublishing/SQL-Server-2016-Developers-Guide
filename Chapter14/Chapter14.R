# --------------------------------------------------------------------------------------
# --------	SQL Server 2016 Developer's Guide ------------------------------------------
# ----- Chapter 14 - Data Exploration and Predictive Modeling with R in SQL Server -----
# --------------------------------------------------------------------------------------

# ----------------------------------------------------
# -- Section 1: Intermediate Statistics - Associations
# ----------------------------------------------------


# Importing Target mail data
# Reading a data frame from a CSV file and attaching it
TM = read.table("C:\\SQL2016DevGuide\\Chapter14_TM.csv",
                sep=",", header=TRUE,
                stringsAsFactors = TRUE);
attach(TM);


# Education is ordered
Education = factor(Education, order=TRUE, 
                   levels=c("Partial High School", 
                            "High School","Partial College",
                            "Bachelors", "Graduate Degree"));
plot(Education, main = 'Education',
     xlab='Education', ylab ='Number of Cases',
     col="purple");

# Crosstabulation with table() and xtabs()
table(Education, Gender, BikeBuyer);
table(NumberCarsOwned, BikeBuyer);
xtabs(~Education + Gender + BikeBuyer);
xtabs(~NumberCarsOwned + BikeBuyer);

# Storing tables in objects
tEduGen <- xtabs(~ Education + Gender);
tNcaBik <- xtabs(~ NumberCarsOwned + BikeBuyer);

# Test of independece
chisq.test(tEduGen);
chisq.test(tNcaBik);

summary(tEduGen);
summary(tNcaBik);

# Installing and loading the vcd package
install.packages("vcd");
library(vcd);

# Measures of association
assocstats(tEduGen);
assocstats(tNcaBik);

# Visualizing the crosstabulation
# Showing expected and observed frequencies
strucplot(tNcaBik, residuals = NULL, shade = TRUE,
          gp = gpar(fill=c("yellow", "blue")),
          type = "expected", main = "Expected");
strucplot(tNcaBik, residuals = NULL, shade = TRUE,
          gp = gpar(fill=c("yellow", "blue")),
          type = "observed", main = "Observed");


# Covariance and correlations

# Pearson
x <- TM[,c("YearlyIncome", "Age", "NumberCarsOwned")];
cov(x);
cor(x);

# Spearman
y <- TM[,c("TotalChildren", "NumberChildrenAtHome", "HouseOwnerFlag", "BikeBuyer")];
cor(y);
cor(y, method = "spearman");

# Two matrices correlations
cor(y,x);

# Visualizing the correlations
install.packages("corrgram");
library(corrgram);
corrgram(y, order = TRUE, lower.panel = panel.shade,
         upper.panel = panel.shade, text.panel = panel.txt,
         cor.method = "spearman", main = "Corrgram");


# Continuous and discrete variables

# T-test
t.test(YearlyIncome ~ Gender);
t.test(YearlyIncome ~ HouseOwnerFlag);
# Error - t-test supports only two groups
t.test(YearlyIncome ~ Education);

# Visualizing the associations
boxplot(YearlyIncome ~ Gender,
        main = "Yearly Income in Groups",
        ylab = "Yearly Income",
        xlab = "Gender");
boxplot(YearlyIncome ~ HouseOwnerFlag,
        main = "Yearly Income in Groups",
        notch = TRUE,
        varwidth = TRUE,
        col = "orange",
        ylab = "Yearly Income",
        xlab = "House Owner Flag");


# Don't forget - Education is ordered
Education = factor(Education, order=TRUE, 
                   levels=c("Partial High School", 
                            "High School","Partial College",
                            "Bachelors", "Graduate Degree"));
# One-way ANOVA
aggregate(YearlyIncome, by = list(Education), FUN = mean);
aggregate(YearlyIncome, by = list(Education), FUN = sd);
AssocTest <- aov(YearlyIncome ~ Education);
summary(AssocTest);

# Visualizing ANOVA
boxplot(YearlyIncome ~ Education,
        main = "Yearly Income in Groups",
        notch = TRUE,
        varwidth = TRUE,
        col = "orange",
        ylab = "Yearly Income",
        xlab = "Education");

# Load gplots
library(gplots);
plotmeans(YearlyIncome ~ Education,
          bars = TRUE, p = 0.99, barwidth = 3,
          col = "red", lwd = 3,
          main = "Yearly Income in Groups",          
          ylab = "Yearly Income",
          xlab = "Education")


# A smaller data frame for the purpose of graph
TMLM <- TM[1:100, c("YearlyIncome", "Age")];
# Removing the TM data frame from the search path
detach(TM);
# Adding the smaller data frame to the search path
attach(TMLM);

# Plot the data points
plot(Age, YearlyIncome, 
     cex = 2, col = "orange", lwd = 2);

# Simple linear regression model
LinReg1 <- lm(YearlyIncome ~ Age);
summary(LinReg1);

# Polynomial  regression
LinReg2 <- lm(YearlyIncome ~ Age + I(Age ^ 2));
summary(LinReg2);

# Visualization
plot(Age, YearlyIncome, 
     cex = 2, col = "orange", lwd = 2);
abline(LinReg1,
       col = "red", lwd = 2);
lines(lowess(Age, YearlyIncome),
      col = "blue", lwd = 2);

# Removing the smaller data frame from the search path
detach(TMLM);


# ----------------------------------------------------
# -- Section 2: PCA, EFA, and Clustering - Undirected
# ----------------------------------------------------


# In case it is needed - re-read the TM data
TM = read.table("C:\\SQL2016DevGuide\\Chapter14_TM.csv",
                sep=",", header=TRUE,
                stringsAsFactors = TRUE);

# Extracting numerical data only
TMPCAEFA <- TM[, c("TotalChildren", "NumberChildrenAtHome",
                   "HouseOwnerFlag", "NumberCarsOwned",
                   "BikeBuyer", "YearlyIncome", "Age")];

# PCA from the base installation
pcaBasic <- princomp(TMPCAEFA, cor = TRUE);
summary(pcaBasic);
plot(pcaBasic, main = "PCA Basic", col = "blue");


# Package psych functions used for PCA and EFA
install.packages("psych");
library(psych);

# PCA unrotated
pcaTM_unrotated <- principal(TMPCAEFA, nfactors = 2, rotate = "none");
pcaTM_unrotated;

# PCA varimax rotation
pcaTM_varimax <- principal(TMPCAEFA, nfactors = 2, rotate = "varimax");
pcaTM_varimax;

# Biplots
biplot.psych(pcaTM_unrotated, cex = c(0.1,2), main = "PCA Unrotated");
biplot.psych(pcaTM_varimax, cex = c(0.1,2), main = "PCA Varimax");


# EFA unrotated
efaTM_unrotated <- fa(TMPCAEFA, nfactors = 2, rotate = "none");
efaTM_unrotated;

# EFA varimax
efaTM_varimax <- fa(TMPCAEFA, nfactors = 2, rotate = "varimax");
efaTM_varimax;

# EFA promax
efaTM_promax <- fa(TMPCAEFA, nfactors = 2, rotate = "promax");
efaTM_promax;

# Plots
factor.plot(efaTM_unrotated, 
            labels = rownames(efaTM_unrotated$loadings), 
            title = "EFA Unrotated");
factor.plot(efaTM_varimax, 
            labels = rownames(efaTM_varimax$loadings), 
            title = "EFA Varimax");
factor.plot(efaTM_promax, 
            labels = rownames(efaTM_promax$loadings), 
            title = "EFA Promax");
fa.diagram(efaTM_unrotated, simple = FALSE,
           main = "EFA Unrotated");
fa.diagram(efaTM_varimax, simple = FALSE,
           main = "EFA Varimax");
fa.diagram(efaTM_promax, simple = FALSE,
           main = "EFA Promax");


# Clustering 

# Hierarchical clustering
# Subset of the data
TM50 <- TM[sample(1:nrow(TM), 50, replace=FALSE),
           c("TotalChildren", "NumberChildrenAtHome", 
             "HouseOwnerFlag", "NumberCarsOwned", 
             "BikeBuyer", "YearlyIncome", "Age")];
# create a distance matrix from the data
ds <- dist(TM50, method = "euclidean") ;
# Hierarchical clustering model
TMCL <- hclust(ds, method="ward.D2");
# Display the dendrogram
plot(TMCL, xlab = NULL, ylab = NULL);
# Cut tree into 2 clusters
groups <- cutree(TMCL, k = 2);
# Draw red borders around the 2 clusters 
rect.hclust(TMCL, k = 2, border = "red");

# K-Means clustering example in chapter 13


# ----------------------------------------------------
# -- Section 3: LogReg, DTrees - Directed
# ----------------------------------------------------

# In case it is needed - re-read the TM data
TM = read.table("C:\\SQL2016DevGuide\\Chapter14_TM.csv",
                sep=",", header=TRUE,
                stringsAsFactors = TRUE);

# Education is ordered
TM$Education = factor(TM$Education, order=TRUE, 
                      levels=c("Partial High School", 
                               "High School","Partial College",
                               "Bachelors", "Graduate Degree"));

# Giving labels to BikeBuyer values
TM$BikeBuyer <- factor(TM$BikeBuyer,
                       levels = c(0,1),
                       labels = c("No","Yes"));


# Preparing the training and test sets

# Setting the seed to make the split reproducible
set.seed(1234);
# Split the data set
train <- sample(nrow(TM), 0.7 * nrow(TM));
TM.train <- TM[train,];
TM.test <- TM[-train,];
# Checking the split
table(TM.train$BikeBuyer);
table(TM.test$BikeBuyer);

# Logistic regression from the base installation
# Three input variables only
TMLogR <- glm(BikeBuyer ~
              YearlyIncome + Age + NumberCarsOwned,
              data=TM.train, family=binomial());

# Test the model
probLR <- predict(TMLogR, TM.test, type = "response");
predLR <- factor(probLR > 0.5,
                 levels = c(FALSE, TRUE),
                 labels = c("No","Yes"));
perfLR <- table(TM.test$BikeBuyer, predLR,
                dnn = c("Actual", "Predicted"));
perfLR;
# Not good

# Logistic regression from the base installation
# All input variables
TMLogR <- glm(BikeBuyer ~
              MaritalStatus + Gender +
              TotalChildren + NumberChildrenAtHome +
              Education + Occupation +
              HouseOwnerFlag + NumberCarsOwned +
              CommuteDistance + Region +
              YearlyIncome + Age,
              data=TM.train, family=binomial());

# Test the model
probLR <- predict(TMLogR, TM.test, type = "response");
predLR <- factor(probLR > 0.5,
                 levels = c(FALSE, TRUE),
                 labels = c("No","Yes"));
perfLR <- table(TM.test$BikeBuyer, predLR,
                dnn = c("Actual", "Predicted"));
perfLR;
# Slightly better

# Manually define other factors
TM$TotalChildren = factor(TM$TotalChildren, order=TRUE);
TM$NumberChildrenAtHome = factor(TM$NumberChildrenAtHome, order=TRUE);
TM$NumberCarsOwned = factor(TM$NumberCarsOwned, order=TRUE);
TM$HouseOwnerFlag = factor(TM$HouseOwnerFlag, order=TRUE);

# Repeating the split
# Setting the seed to make the split reproducible
set.seed(1234);
# Split the data set
train <- sample(nrow(TM), 0.7 * nrow(TM));
TM.train <- TM[train,];
TM.test <- TM[-train,];
# Checking the split
table(TM.train$BikeBuyer);
table(TM.test$BikeBuyer);

# Logistic regression from the base installation
# All input variables, factors defined manually
TMLogR <- glm(BikeBuyer ~
                MaritalStatus + Gender +
                TotalChildren + NumberChildrenAtHome +
                Education + Occupation +
                HouseOwnerFlag + NumberCarsOwned +
                CommuteDistance + Region +
                YearlyIncome + Age,
              data=TM.train, family=binomial());

# Test the model
probLR <- predict(TMLogR, TM.test, type = "response");
predLR <- factor(probLR > 0.5,
                 levels = c(FALSE, TRUE),
                 labels = c("No","Yes"));
perfLR <- table(TM.test$BikeBuyer, predLR,
                dnn = c("Actual", "Predicted"));
perfLR;
# Again, slightly better


# Decision trees from the base installation
TMDTree <- rpart(BikeBuyer ~ MaritalStatus + Gender +
                 TotalChildren + NumberChildrenAtHome +
                 Education + Occupation +
                 HouseOwnerFlag + NumberCarsOwned +
                 CommuteDistance + Region +
                 YearlyIncome + Age,
                 method="class", data=TM.train);

# Plot the tree
install.packages("rpart.plot");
library(rpart.plot);
prp(TMDTree, type = 2, extra = 104, fallen.leaves = FALSE);

# Predictions on the test data set
predDT <- predict(TMDTree, TM.test, type = "class");
perfDT <- table(TM.test$BikeBuyer, predDT,
                dnn = c("Actual", "Predicted"));
perfDT;
# Somehow better

# Package party (Decision Trees)
install.packages("party", dependencies = TRUE);
library("party");

# Train the model with defaults
TMDT <- ctree(BikeBuyer ~ MaritalStatus + Gender +
              TotalChildren + NumberChildrenAtHome +
              Education + Occupation +
              HouseOwnerFlag + NumberCarsOwned +
              CommuteDistance + Region +
              YearlyIncome + Age,
              data=TM.train);

# Predictions
predDT <- predict(TMDT, TM.test, type = "response");
perfDT <- table(TM.test$BikeBuyer, predDT,
                dnn = c("Actual", "Predicted"));
perfDT;
# Much better

# Train the model with more splits forced
TMDT <- ctree(BikeBuyer ~ MaritalStatus + Gender +
              TotalChildren + NumberChildrenAtHome +
              Education + Occupation +
              HouseOwnerFlag + NumberCarsOwned +
              CommuteDistance + Region +
              YearlyIncome + Age,
              data=TM.train, 
              controls = ctree_control(mincriterion = 0.70));

# Predictions
predDT <- predict(TMDT, TM.test, type = "response");
perfDT <- table(TM.test$BikeBuyer, predDT,
                dnn = c("Actual", "Predicted"));
perfDT;
# Even better


# ----------------------------------------------------
# -- Section 4: GGPlot
# ----------------------------------------------------

install.packages("ggplot2");
library("ggplot2");

# Plots with count (number) Education by Region
ggplot (TM, aes(Region, fill=Education)) + 
  geom_bar(position = "stack");

ggplot (TM, aes(Region, fill=Education)) +
  geom_bar(position="fill");

ggplot (TM, aes(Region, fill=Education)) +
  geom_bar(position="dodge");


# A smaller data frame for the purpuse of graph
TMLM <- TM[1:100, c("YearlyIncome", "Age")];

# Plot the data points
plot(TMLM$Age, TMLM$YearlyIncome, 
     cex = 2, col = "orange", lwd = 2);
# Plots with ggplot
# Basic
ggplot(data = TMLM, aes(x=Age, y=YearlyIncome)) +
  geom_point();

# Plot with a Lowess line
plot(TMLM$Age, TMLM$YearlyIncome, 
     cex = 2, col = "orange", lwd = 2);
lines(lowess(TMLM$Age, TMLM$YearlyIncome),
      col = "blue", lwd = 2);

# With ggplot - linear + loess
ggplot(data = TMLM, aes(x=Age, y=YearlyIncome)) +
  geom_point() +
  geom_smooth(method = "lm", color = "red") +
  geom_smooth(color = "blue");


# Boxplot
boxplot(TM$YearlyIncome ~ TM$Education,
        main = "Yearly Income in Groups",
        notch = TRUE,
        varwidth = TRUE,
        col = "orange",
        ylab = "Yearly Income",
        xlab = "Education");

# Boxplot with ggplot
ggplot(TM, aes (x = Education, y = YearlyIncome)) +
  geom_boxplot(fill = "orange",
               color = "blue", notch = TRUE);

# Boxplot and violin plot with ggplot
ggplot(TM, aes (x = Education, y = YearlyIncome)) +
  geom_violin(fill = "lightgreen") + 
  geom_boxplot(fill = "orange",
               width = 0.2);

# Density plot
ggplot(TM, aes(x = YearlyIncome, fill = Education)) +
  geom_density(alpha = 0.3);

# Trellis charts
ggplot(TM, aes(x = NumberCarsOwned, fill = Region)) + 
  geom_bar(stat = "bin") +
  facet_grid(MaritalStatus ~ BikeBuyer) +
  theme(text = element_text(size=30));

# More exaples
ggplot(TM, aes(NumberCarsOwned) ) + 
  geom_histogram() +
  facet_grid(MaritalStatus ~ .);

ggplot(TM, aes(x = Education,y = BikeBuyer, fill = Region)) +
  geom_bar(stat = "identity") +
  facet_grid(. ~ Region) +  
  theme(legend.position="none",axis.text.x=element_text(angle=45));

# End of script

