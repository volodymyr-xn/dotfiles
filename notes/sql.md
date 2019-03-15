### Find duplicates

```sql
  SELECT
    firstname,
    lastname,
    count(*)
  FROM people
  GROUP BY
    firstname,
    lastname
  HAVING count(*) > 1;
```
