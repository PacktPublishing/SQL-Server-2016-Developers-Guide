# ----------------------------------------------------
# --------	SQL Server 2016 Developer's Guide --------
# ----- Chapter 13 - Supporting R in SQL Server  -----
# ----------------------------------------------------

# ----------------------------------------------------
# -- Section 1: Introducing R
# ----------------------------------------------------


# R Contributors
contributors();

# If you want to quit
q();

# Getting help on help
help();
# General help
help.start();
# Help about global options
help("options");
# Help on the function exp()
help("exp");
?"exp";
# Examples for the function exp()
example("exp");
# Search
help.search("constants");
??"constants";
# Online search 
RSiteSearch("exp");

# Demonsstrate graphics capabilities
demo("graphics");

# Pie chart example
pie.sales <- c(0.12, 0.3, 0.26, 0.16, 0.04, 0.12);
names(pie.sales) <- c("Blueberry", "Cherry", "Apple",
                      "Boston Cream", "Other", "Vanilla Cream");
pie(pie.sales,
    col = c("purple","violetred1","green3","cornsilk","cyan","white"));

title(main = "January Pie Sales", cex.main = 1.8, font.main = 1);
title(xlab = "(Don't try this at home kids)", cex.lab = 0.8, font.lab = 3);

# List of the current objects in the workspace
objects();
ls();

sink("C:\\SQL2016DevGuide\\Ch13.txt")
dev.off;
sink()

# Basic expressions
1 + 1;
2 + 3 * 4;
3 ^ 3;
sqrt(81);
pi;

# Check the built-in constants
??"constants";

# Sequences
rep(1,10);
3:7;         
seq(3,7);
seq(5,17,by=3);      


# Variables
x <- 2;
y <- 3;
z <- 4;
x + y * z;
# Names are case-sensitive
X + Y + Z;
# Can use period
This.Year <- 2016;
This.Year;
# Equals as an assigment operator
x = 2;
y = 3;
z = 4;
x + y * z;
# Boolean equality test
x <- 2;
x == 2;


# Vectors
x <- c(2,0,0,4);       
assign("y", c(1,9,9,9)); 
c(5,4,3,2) -> z;              
q = c(1,2,3,4);         
# Vector operations
x + y;
x * 4;
sqrt(x);

# Vector elements
x <- c(2,0,0,4);  
x[1];               # Select the first element
x[-1];              # Exclude the first element
x[1] <- 3; x;       # Assign a value to the first element
x[-1] = 5; x;       # Assign a value to all other elements
y <- c(1,9,9,9);
y < 8;             # Compares each element, returns result as vector
y[4] = 1;
y < 8;
y[y<8] = 2; y # Edits elements marked as TRUE in index vector

# Check the installed packages
installed.packages();
# Library location
.libPaths();
library();

# Reading from SQL Server
# Install RODBC library
install.packages("RODBC");
# Load RODBC library
library(RODBC);
# Getting help about RODBC
help(package = "RODBC");

# Connect to WWIDW
# WWIDW system DSN created in advance
con <- odbcConnect("WWIDW", uid="RUser", pwd="Pa$$w0rd");
sqlQuery(con, 
         "SELECT c.Customer,
            SUM(f.Quantity) AS TotalQuantity,
            SUM(f.[Total Excluding Tax]) AS TotalAmount,
            COUNT(*) AS SalesCount
          FROM Fact.Sale AS f
           INNER JOIN Dimension.Customer AS c
            ON f.[Customer Key] = c.[Customer Key]
          WHERE c.[Customer Key] <> 0
          GROUP BY c.Customer
          HAVING COUNT(*) > 400
          ORDER BY SalesCount DESC;");


# ----------------------------------------------------
# -- Section 2: Manipulating data
# ----------------------------------------------------


# Matrix
x = c(1,2,3,4,5,6); x;         # A simple vector
Y = array(x, dim=c(2,3)); Y;   # A matrix from the vector - fill by columns
Z = matrix(x,2,3,byrow=F); Z;  # A matrix from the vector - fill by columns
U = matrix(x,2,3,byrow=T); U;  # A matrix from the vector - fill by rows
rnames = c("Row1", "Row2");
cnames = c("Col1", "Col2", "Col3");
V = matrix(x,2,3,byrow=T, dimnames = list(rnames, cnames)); V;  # names

# Elements of a matrix
U[1,];
U[1,c(2,3)];
U[,c(2,3)];
V[,c("Col2", "Col3")];

# Array
rnames = c("Row1", "Row2");
cnames = c("Col1", "Col2", "Col3");
pnames = c("Page1", "Page2", "Page3");
Y = array(1:18, dim=c(2,3,3), dimnames = list(rnames, cnames, pnames)); Y;


# Factor
x = c("good", "moderate", "good", "bad", "bad", "good");
y = factor(x); y;  
z = factor(x, order=TRUE); z;
w = factor(x, order=TRUE, 
           levels=c("bad", "moderate","good")); w;

# List
L = list(name1="ABC", name2="DEF",
         no.children=2, children.ages=c(3,6));
L;
L[[1]];
L[[4]];
L[[4]][2];

# Data frame
CategoryId = c(1,2,3,4);
CategoryName = c("Bikes", "Components", "Clothing", "Accessories");
ProductCategories = data.frame(CategoryId, CategoryName);
ProductCategories;

# Reading a data frame from a CSV file
TM = read.table("C:\\SQL2016DevGuide\\Chapter13_TM.csv",
                sep=",", header=TRUE, row.names = "CustomerKey",
                stringsAsFactors = TRUE);
TM[1:5,1:4];

# Accessing data in a data frame
TM[1:2];                              # Two columns
TM[c("MaritalStatus", "Gender")];     # Two columns
TM[1:3,1:2];                          # Three rows, two columns
TM[1:3,c("MaritalStatus", "Gender")]; # Three rows, two columns

# $ Notation
table(TM$MaritalStatus, TM$Gender);
attach(TM);
table(MaritalStatus, Gender);
detach(TM);
with(TM,
     {table(MaritalStatus, Gender)});


# Value labels
table(TM$BikeBuyer, TM$Gender);
TM$BikeBuyer <- factor(TM$BikeBuyer,
                       levels = c(0,1),
                       labels = c("No","Yes"));
table(TM$BikeBuyer, TM$Gender);

# Metadata
class(TM);
names(TM);
length(TM);
dim(TM);
str(TM);

# Recoding and adding variables
TM <- within(TM, {
  MaritalStatusInt <- NA
  MaritalStatusInt[MaritalStatus == "S"] <- 0
  MaritalStatusInt[MaritalStatus == "M"] <- 1
});
str(TM);

# Changing the data type
TM$MaritalStatusInt <- as.integer(TM$MaritalStatusInt);
str(TM);

# Adding another variable
TM$HouseholdNumber = as.integer(
  1 + TM$MaritalStatusInt + TM$NumberChildrenAtHome);
str(TM);

# Missing values
x <- c(1,2,3,4,5,NA);
is.na(x);
mean(x);
mean(x, na.rm = TRUE);

# Projection datasets
# Re-read the TM dataset without row.names
TM = read.table("C:\\SQL2016DevGuide\\Chapter13_TM.csv",
                sep=",", header=TRUE,
                stringsAsFactors = TRUE);
TM[1:3,1:3];
cols1 <- c("CustomerKey", "MaritalStatus");
TM1 <- TM[cols1];
cols2 <- c("CustomerKey", "Gender");
TM2 <- TM[cols2];
TM1[1:3, 1:2];
TM2[1:3, 1:2];

# Merge datasets
TM3 <- merge(TM1, TM2, by = "CustomerKey");
TM3[1:3, 1:3];

# Binding datasets
TM4 <- cbind(TM1, TM2);
TM4[1:3, 1:4];

# Filtering and row binding data
TM1 <- TM[TM$CustomerKey < 11002, cols1];
TM2 <- TM[TM$CustomerKey > 29481, cols1];
TM5 <- rbind(TM1, TM2);
TM5;

# Sort 
TMSortedByAge <- TM[order(-TM$Age),c("CustomerKey", "Age")];
TMSortedByAge[1:5,1:2];


# ----------------------------------------------------
# -- Section 3: Understanding the data
# ----------------------------------------------------

# Re-read the TM dataset 
TM = read.table("C:\\SQL2016DevGuide\\Chapter13_TM.csv",
                sep=",", header=TRUE,
                stringsAsFactors = TRUE);
attach(TM);

# A simple distribution
plot(Education);

# Education is ordered
Education = factor(Education, order=TRUE, 
                   levels=c("Partial High School", 
                            "High School","Partial College",
                            "Bachelors", "Graduate Degree"));
plot(Education, main = 'Education',
     xlab='Education', ylab ='Number of Cases',
     col="purple");


# Generating a subset data frame
cols1 <- c("CustomerKey", "NumberCarsOwned", "TotalChildren");
TM1 <- TM[TM$CustomerKey < 11010, cols1];
names(TM1) <- c("CustomerKey1", "NumberCarsOwned1", "TotalChildren1");
attach(TM1);

# Generating a table from NumberCarsOwned and BikeBuyer
nofcases <- table(NumberCarsOwned, BikeBuyer);
nofcases;

# Saving parameters
oldpar <- par(no.readonly = TRUE);

# Defining a 2x2 graph
par(mfrow=c(2,2));

# Education and marital status
plot(Education, MaritalStatus,
     main='Education and marital status',
     xlab='Education', ylab ='Marital Status',
     col=c("blue", "yellow"));

# Histogram with a title and axis labels and color
hist(NumberCarsOwned, main = 'Number of cars owned',
     xlab='Number of Cars Owned', ylab ='Number of Cases',
     col="blue");

# Plot with two lines, title, legend, and axis legends
plot_colors=c("blue", "red");
plot(TotalChildren1, 
     type="o",col='blue', lwd=2,
     xlab="Key",ylab="Number");
lines(NumberCarsOwned1, 
      type="o",col='red', lwd=2);
legend("topleft", 
       c("TotalChildren", "NumberCarsOwned"),
       cex=1.4,col=plot_colors,lty=1:2,lwd=1, bty="n");
title(main="Total children and number of cars owned line chart", 
      col.main="DarkGreen", font.main=4);

# NumberCarsOwned and BikeBuyer grouped bars
barplot(nofcases,
        main='Number of cars owned and bike buyer gruped',    
        xlab='BikeBuyer', ylab ='NumberCarsOwned',
        legend=rownames(nofcases),
        col=c("black", "blue", "red", "orange", "yellow"),
        beside=TRUE);

# Restoring the default graphical parameters
par(oldpar);

# removing the data frames from the search path
detach(TM);
detach(TM1);


# Descriptive statistics
# Re-read the TM dataset 
TM = read.table("C:\\SQL2016DevGuide\\Chapter13_TM.csv",
                sep=",", header=TRUE,
                stringsAsFactors = TRUE);
attach(TM);
# Education is ordered
Education = factor(Education, order=TRUE, 
                   levels=c("Partial High School", 
                            "High School","Partial College",
                            "Bachelors", "Graduate Degree"));

# A quick summary for the whole dataset
summary(TM);

# A quick summary for Age
summary(Age);
# Details for Age
mean(Age);
median(Age);
min(Age);
max(Age);
range(Age);
quantile(Age, 1/4);
quantile(Age, 3/4);
IQR(Age);
var(Age);
sd(Age);

# Skewness and kurtosis - package moments
install.packages("moments");
library(moments);
skewness(Age);
kurtosis(Age);

# Custom function for skewness and kurtosis
skewkurt <- function(p){
  avg <- mean(p)
  cnt <- length(p)
  stdev <- sd(p)
  skew <- sum((p-avg)^3/stdev^3)/cnt
  kurt <- sum((p-avg)^4/stdev^4)/cnt-3
  return(c(skewness=skew, kurtosis=kurt))
};
skewkurt(Age);

# Frequencies
# Summary gives absolute frequencies only
summary(Education);
# table and table.prop
edt <- table(Education);
edt;
prop.table(edt);

# Package descr
install.packages("descr");
library(descr);
freq(Education);

# Clean up
detach(TM);


# ----------------------------------------------------
# -- Section 4: SQL Server R Services
# ----------------------------------------------------


# Set the execution context to the server
# Define SQL Server connection string
sqlConnStr <- "Driver=SQL Server;Server=localhost;
 Database=AdventureWorksDW2014;Uid=RUser;Pwd=Pa$$w0rd";
# Share to exchange data with SQL Server
sqlShare <- "C:\\SQL2016DevGuide";
# Define the chunk size
chunkSize = 1000;
# Create a server execution context
srvEx <- RxInSqlServer(connectionString = sqlConnStr, shareDir = sqlShare,
                       wait = TRUE, consoleOutput = FALSE);
rxSetComputeContext(srvEx);

# Import the data from a .CSV file
TMCSV = rxImport(inData = "C:\\SQL2016DevGuide\\Chapter13_TM.csv",
                 stringsAsFactors = TRUE, type = "auto",
                 rowsPerRead = chunkSize, reportProgress = 3);

# A query
TMquery <- 
"SELECT CustomerKey, MaritalStatus, Gender,
  TotalChildren, NumberChildrenAtHome,
  EnglishEducation AS Education,
  EnglishOccupation AS Occupation,
  HouseOwnerFlag, NumberCarsOwned, CommuteDistance,
  Region, BikeBuyer,
  YearlyIncome, Age
 FROM dbo.vTargetMail";

# Generate SqlServer data source object
sqlTM <- RxSqlServerData(sqlQuery = TMquery,
                         connectionString = sqlConnStr,
                         stringsAsFactors = TRUE,
                         rowsPerRead = chunkSize);

# Import data to a data frame
TMSQL <- rxImport(inData = sqlTM, reportProgress = 3);


# Info about the SQL data source and the data frames with imported data
rxGetInfo(TMSQL);
rxGetInfo(TMCSV);
rxGetInfo(sqlTM);

# Info about the variables
rxGetVarInfo(sqlTM);

# Compute summary statistics 
sumOut <- rxSummary(
  formula = ~ NumberCarsOwned + Occupation + F(BikeBuyer),
  data = sqlTM);
sumOut;

# Crosstabulation object
cTabs <- rxCrossTabs(formula = BikeBuyer ~
                     Occupation : F(HouseOwnerFlag), 
                     data = sqlTM);
# Check the results
print(cTabs, output = "counts");
print(cTabs, output = "sums");
print(cTabs, output = "means");
summary(cTabs, output = "sums");
summary(cTabs, output = "counts");
summary(cTabs, output = "means");

# Crosstabulation in a different way
cCube <- rxCube(formula = BikeBuyer ~
                Occupation : F(HouseOwnerFlag), 
                data = sqlTM);
# Check the results
cCube;

# Histogram
rxHistogram(formula = ~ BikeBuyer | MaritalStatus,
            data = sqlTM);

# Set the compute context back to local
rxSetComputeContext("local");


# K-Means Clustering
TwoClust <- rxKmeans(formula = ~ BikeBuyer + TotalChildren + NumberCarsOwned,
                     data = TMSQL,
                     numClusters = 2);
summary(TwoClust);


# Add cluster membership to the original data frame and rename the variable
TMClust <- cbind(TMSQL, TwoClust$cluster);
names(TMClust)[15] <- "ClusterID";

# Attach the new data frame
attach(TMClust);

# Saving parameters
oldpar <- par(no.readonly = TRUE);

# Defining a 1x3 graph
par(mfrow=c(1,3));

# NumberCarsOwned and clusters
nofcases <- table(NumberCarsOwned, ClusterID);
nofcases;
barplot(nofcases,
        main='Number of cars owned and cluster ID',    
        xlab='Cluster Id', ylab ='Number of Cars',
        legend=rownames(nofcases),
        col=c("black", "blue", "red", "orange", "yellow"),
        beside=TRUE);
# BikeBuyer and clusters
nofcases <- table(BikeBuyer, ClusterID);
nofcases;
barplot(nofcases,
        main='Bike buyer and cluster ID',    
        xlab='Cluster Id', ylab ='BikeBuyer',
        legend=rownames(nofcases),
        col=c("blue", "yellow"),
        beside=TRUE);
# TotalChildren and clusters
nofcases <- table(TotalChildren, ClusterID);
nofcases;
barplot(nofcases,
        main='Total children and cluster ID',    
        xlab='Cluster Id', ylab ='Total Children',
        legend=rownames(nofcases),
        col=c("black", "blue", "green", "red", "orange", "yellow"),
        beside=TRUE);

# Clean up
par(oldpar);
detach(TMClust);


# Create a Logistic Regression model to predict BikeBuyer
# Set compute context back to SQL Server
rxSetComputeContext(srvEx);
# Create the model
bbLogR <- rxLogit(BikeBuyer ~
                    NumberCarsOwned + TotalChildren + Age + YearlyIncome,
                  data = sqlTM);
# See the summary of the model
summary(bbLogR);

# Prepare a SQL Server table for storing predictions
bbLogRPredict <- RxSqlServerData(connectionString = sqlConnStr,
                                 table = "dbo.TargetMailLogR");

# Store the predictions in SQL Server
rxPredict(modelObject = bbLogR,
          data = sqlTM, outData = bbLogRPredict,
          predVarNames = "BikeBuyerPredict", 
          type = "response", writeModelVars = TRUE);

# Store the model in SQL Server
library(RODBC);
conn <- odbcDriverConnect(sqlConnStr);

# Serialize a model   
modelbin <- serialize(bbLogR, NULL);
modelbinstr=paste(modelbin, collapse="");

# persist model by calling a stored procedure from SQL Server 
sqlQ <- paste("EXEC dbo.InsertModel @modelname='bbLogR', @model='", 
               modelbinstr,"'", sep="");
sqlQuery(conn, sqlQ);

# End of script

