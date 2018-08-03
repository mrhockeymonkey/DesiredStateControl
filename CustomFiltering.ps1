@{
    Snowflake_App = {$_.NodeName -match 'snowapp'}
    Snowflake_Web = {$_.Property -in 'web','website'}
}
