-- 1 current head count by department
SELECT 
    d.Name AS DepartmentName,
    d.GroupName,
    COUNT(edh.BusinessEntityID) AS ActiveEmployeeCount
FROM
    HumanResources_Department d
        JOIN
    HumanResources_EmployeeDepartmentHistory edh ON d.DepartmentID = edh.DepartmentID
WHERE
    edh.EndDate IS NULL
GROUP BY d.Name , d.GroupName
ORDER BY ActiveEmployeeCount DESC;

-- 2 average pay per department 
SELECT 
    d.Name AS DepartmentName,
    AVG(eph.Rate) AS AveragePayRate,
    MIN(eph.Rate) AS MinPayRate,
    MAX(eph.Rate) AS MaxPayRate
FROM HumanResources_Department d
JOIN HumanResources_EmployeeDepartmentHistory edh ON d.DepartmentID = edh.DepartmentID
JOIN HumanResources_EmployeePayHistory eph ON edh.BusinessEntityID = eph.BusinessEntityID
WHERE edh.EndDate IS NULL
GROUP BY d.Name
ORDER BY AveragePayRate DESC;

-- 3 employee distribution by shift work
SELECT 
    s.Name AS ShiftName,
    s.StartTime,
    s.EndTime,
    COUNT(edh.BusinessEntityID) AS EmployeeCount
FROM HumanResources_Shift s
JOIN HumanResources_EmployeeDepartmentHistory edh ON s.ShiftID = edh.ShiftID
WHERE edh.EndDate IS NULL
GROUP BY s.Name, s.StartTime, s.EndTime
ORDER BY EmployeeCount DESC;


-- 4 genderbreakdown across job roles
SELECT 
    e.JobTitle,
    e.Gender,
    COUNT(*) AS EmployeeCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY e.JobTitle) AS DECIMAL(5,2)) AS PercentageInRole
FROM HumanResources_Employee e
GROUP BY e.JobTitle, e.Gender
ORDER BY e.JobTitle, EmployeeCount DESC;

-- 5 Top 10 Longest-Serving Active Employees
SELECT 
    p.FirstName,
    p.LastName,
    e.JobTitle,
    e.HireDate,
    DATEDIFF(YEAR, e.HireDate, GETDATE()) AS YearsOfService
FROM HumanResources_Employee e
JOIN Person_Person p ON e.BusinessEntityID = p.BusinessEntityID
WHERE e.CurrentFlag = 1
ORDER BY e.HireDate ASC;

-- 6 recent hires tracking 
SELECT 
    p.FirstName,
    p.LastName,
    e.JobTitle,
    d.Name AS Department,
    e.HireDate
FROM humanresources_employee e
JOIN person_person p ON e.BusinessEntityID = p.BusinessEntityID
JOIN humanresources_employeedepartmenthistory edh ON e.BusinessEntityID = edh.BusinessEntityID AND edh.EndDate IS NULL
JOIN humanresources_department d ON edh.DepartmentID = d.DepartmentID
WHERE e.HireDate >= DATE_SUB(CURDATE(), INTERVAL 8 YEAR) -- Adjust threshold as needed
ORDER BY e.HireDate DESC;

-- 7 employee pay history and pay progression 
SELECT 
    p.FirstName,
    p.LastName,
    eph.RateChangeDate,
    eph.Rate,
    eph.PayFrequency
FROM HumanResources_EmployeePayHistory eph
JOIN Person_Person p ON eph.BusinessEntityID = p.BusinessEntityID
WHERE eph.BusinessEntityID = 1 -- Replace with target BusinessEntityID
ORDER BY eph.RateChangeDate ASC;

-- 8 geographic distribution of employees
 SELECT 
    sp.Name AS StateProvince,
    a.City,
    COUNT(bea.BusinessEntityID) AS EmployeeCount
FROM Person_BusinessEntityAddress bea
JOIN Person_Address a ON bea.AddressID = a.AddressID
JOIN Person_StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
JOIN HumanResources_Employee e ON bea.BusinessEntityID = e.BusinessEntityID
WHERE e.CurrentFlag = 1
GROUP BY sp.Name, a.City
ORDER BY EmployeeCount DESC;

-- 9 job candidate application and hiring conversion
SELECT 
    COUNT(jc.JobCandidateID) AS TotalApplications,
    SUM(CASE WHEN jc.BusinessEntityID IS NOT NULL THEN 1 ELSE 0 END) AS HiredCandidatesCount,
    CAST(SUM(CASE WHEN jc.BusinessEntityID IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(jc.JobCandidateID) AS DECIMAL(5,2)) AS ConversionRatePercentage
FROM HumanResources_JobCandidate jc;

-- 10 estimated monthly/annual payroll cost per department
SELECT 
    d.Name AS DepartmentName,
    SUM(CASE 
            WHEN eph.PayFrequency = 1 THEN eph.Rate * 12 -- Assuming annual/monthly calculation 
            WHEN eph.PayFrequency = 2 THEN eph.Rate * 2080 -- Hourly rate * standard annual hours
            ELSE eph.Rate * 2080 
        END) AS EstimatedAnnualPayroll
FROM HumanResources_Department d
JOIN HumanResources_EmployeeDepartmentHistory edh ON d.DepartmentID = edh.DepartmentID
JOIN HumanResources_EmployeePayHistory eph ON edh.BusinessEntityID = eph.BusinessEntityID
WHERE edh.EndDate IS NULL
GROUP BY d.Name
ORDER BY EstimatedAnnualPayroll DESC;

-- 11 employee with multiple department history
SELECT 
    p.FirstName,
    p.LastName,
    COUNT(DISTINCT edh.DepartmentID) AS DepartmentsWorkedIn
FROM HumanResources_EmployeeDepartmentHistory edh
JOIN Person_Person p ON edh.BusinessEntityID = p.BusinessEntityID
GROUP BY edh.BusinessEntityID, p.FirstName, p.LastName
HAVING COUNT(DISTINCT edh.DepartmentID) > 1
ORDER BY DepartmentsWorkedIn DESC;

-- 12 employee contact details audit
SELECT 
    e.BusinessEntityID,
    p.FirstName,
    p.LastName,
    CASE WHEN ea.EmailAddress IS NOT NULL THEN 'Yes' ELSE 'No' END AS HasEmail,
    CASE WHEN pp.PhoneNumber IS NOT NULL THEN 'Yes' ELSE 'No' END AS HasPhone
FROM HumanResources_Employee e
JOIN Person_Person p ON e.BusinessEntityID = p.BusinessEntityID
LEFT JOIN Person_EmailAddress ea ON e.BusinessEntityID = ea.BusinessEntityID
LEFT JOIN Person_PersonPhone pp ON e.BusinessEntityID = pp.BusinessEntityID
WHERE e.CurrentFlag = 1;

-- 13 employee demographics: average age by marital status and gender
SELECT 
    e.Gender,
    e.MaritalStatus,
    COUNT(*) AS EmployeeCount,
    AVG(TIMESTAMPDIFF(YEAR, e.BirthDate, CURDATE())) AS AverageAge
FROM humanresources_employee e
WHERE e.CurrentFlag = 1
GROUP BY e.Gender, e.MaritalStatus
ORDER BY e.Gender, e.MaritalStatus;

-- 14 salaries vs. hourly workforce breakdown
SELECT 
    CASE WHEN e.SalariedFlag = 1 THEN 'Salaried' ELSE 'Hourly' END AS EmploymentType,
    COUNT(*) AS EmployeeCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS PercentageOfWorkforce
FROM HumanResources_Employee e
WHERE e.CurrentFlag = 1
GROUP BY e.SalariedFlag;

-- 15 management heirarchy depth
SELECT 
    e.BusinessEntityID,
    p.FirstName,
    p.LastName,
    e.JobTitle,
    e.OrganizationLevel
FROM HumanResources_Employee e
JOIN Person_Person p ON e.BusinessEntityID = p.BusinessEntityID
WHERE e.CurrentFlag = 1
ORDER BY e.OrganizationLevel ASC, e.JobTitle;


 