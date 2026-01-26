#Requires AutoHotkey 2.0

class ServiceContainer {
    static instance := ""
    services := Map()
    singletons := Map()

    static GetInstance() {
        if (!ServiceContainer.instance)
            ServiceContainer.instance := ServiceContainer()
        return ServiceContainer.instance
    }

    ; Register a service factory
    Register(name, factory, singleton := false) {
        this.services[name] := Map("factory", factory, "singleton", singleton)
    }

    ; Get a service instance
    Get(name, params*) {
        if (!this.services.Has(name))
            throw Error("Service '" name "' not registered")

        serviceInfo := this.services[name]

        ; Return singleton if already created
        if (serviceInfo["singleton"] && this.singletons.Has(name))
            return this.singletons[name]

        ; Create new instance
        instance := serviceInfo["factory"].Call(params*)

        ; Store singleton
        if (serviceInfo["singleton"])
            this.singletons[name] := instance

        return instance
    }

    ; Check if service is registered
    Has(name) {
        return this.services.Has(name)
    }
}
