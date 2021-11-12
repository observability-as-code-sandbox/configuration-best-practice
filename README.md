# Configuration-best-practice

## Steps to use Health rules
1) Obtain controller conenction details:
- Controller URL
- Access Token (API Access)

Create .local.token file and paste plaintext token value. 
> Never check-in or version control any of your access details.

2) Prepare

Set "modules to use":

```console
_include_app=false              # applciation health rules
_include_sim=false              # applciation server visibility health rules
_include_cluster_agent=false    # cluster agent (kubernetes) health rules
_include_jvm=false              # applciation jvm health rules
_include_database=false         # database health rules
_include_infrastructure=true    # server/machine agent health rules
```

3) Run

```console
foo@bar:~$ ./import_health_rules.sh https://account-name.saas.appdynamics.com
```

## Steps to use Dashboards

1) Import through the controller UI.

2) Update metrics to fit the environment.