# Accelerated Onboarding: Configuration-best-practice

## Steps to use Health rules
1) Obtain controller connection details:
- Controller URL
- Access Token (API Access)

Create .local.token file and paste plaintext token value. 
> Never check-in or version control any of your access details.

2) Prepare

Set "modules to use":

```console
_include_app=false              # appliciation health rules
_include_sim=false              # appliciation server visibility health rules
_include_cluster_agent=false    # cluster agent (kubernetes) health rules
_include_jvm=false              # appliciation jvm health rules
_include_database=false         # database health rules
_include_infrastructure=true    # server/machine agent health rules
```

3) Run

```console
foo@bar:~$ ./import_health_rules.sh https://account-name.saas.appdynamics.com
```

## Steps to use Dashboards

1) Find and replace `changeme-app`, `changeme-db`, `changeme-server`, `changeme-cluster` values with your target entity names.

2) Import through the controller UI.

3) Update metrics to fit the environment.
