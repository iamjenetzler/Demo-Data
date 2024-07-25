BULK INSERT dbo.[FactOnlineSales_big]
FROM 'C:\Users\jeetzler\OneDrive - Microsoft\VBD\Power BI Clinic\ODP\Demos\salestableBig\salestableBig.txt'
WITH (
    FIELDTERMINATOR = ',',  
    ROWTERMINATOR = '\n',   
    FIRSTROW = 2            
);
