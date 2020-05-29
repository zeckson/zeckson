### Create user to access DB

```sql
CREATE USER '<user name>'@'localhost' IDENTIFIED BY '<password>';
```

### Add privileges to database and table

```sql
GRANT ALL PRIVILEGES ON <database or *> . <table or *> TO '<user name>'@'localhost';
```

### Apply changes

```sql
FLUSH PRIVILEGES;
```
