import Argo
import FBSDKCoreKit
import Foundation
import KsApi
import Prelude
import ReactiveSwift
import Runes
import Optimizely

/**
 A global stack that captures the current state of global objects that the app wants access to.
 */
public struct AppEnvironment: AppEnvironmentType {
  internal static let environmentStorageKey = "com.kickstarter.AppEnvironment.current"
  internal static let oauthTokenStorageKey = "com.kickstarter.AppEnvironment.oauthToken"

  /**
   A global stack of environments.
   */
  fileprivate static var stack: [Environment] = [Environment()]

  /**
   Invoke when an access token has been acquired and you want to log the user in. Replaces the current
   environment with a new one that has the authenticated api service and current user model.

   - parameter envelope: An access token envelope with the api access token and user.
   */
  public static func login(_ envelope: AccessTokenEnvelope) {
    self.replaceCurrentEnvironment(
      apiService: self.current.apiService.login(OauthToken(token: envelope.accessToken)),
      currentUser: envelope.user,
      koala: self.current.koala |> Koala.lens.loggedInUser .~ envelope.user
    )
  }

  /**
   Invoke when we have acquired a fresh current user and you want to replace the current environment's
   current user with the fresh one.

   - parameter user: A user model.
   */
  public static func updateCurrentUser(_ user: User) {
    self.replaceCurrentEnvironment(
      currentUser: user,
      koala: self.current.koala |> Koala.lens.loggedInUser .~ user
    )
  }

  public static func updateDebugData(_ debugData: DebugData) {
    self.replaceCurrentEnvironment(
      debugData: debugData
    )
  }

  public static func updateOptimizelyClient(_ optimizelyClient: KSOptimizelyClientType) {
    self.replaceCurrentEnvironment(
      optimizelyClient: optimizelyClient
    )
  }

  public static func updateServerConfig(_ config: ServerConfigType) {
    let service = Service(serverConfig: config)

    replaceCurrentEnvironment(
      apiService: service
    )
  }

  public static func updateConfig(_ config: Config) {
    let debugConfigOrConfig = self.current.debugData?.config ?? config

    self.replaceCurrentEnvironment(
      config: debugConfigOrConfig,
      countryCode: debugConfigOrConfig.countryCode,
      koala: AppEnvironment.current.koala |> Koala.lens.config .~ debugConfigOrConfig
    )
  }

  public static func updateLanguage(_ language: Language) {
    self.replaceCurrentEnvironment(language: language)
  }

  // Invoke when you want to end the user's session.
  public static func logout() {
    let storage = AppEnvironment.current.cookieStorage
    storage.cookies?.forEach(storage.deleteCookie)

    self.replaceCurrentEnvironment(
      apiService: AppEnvironment.current.apiService.logout(),
      cache: type(of: AppEnvironment.current.cache).init(),
      currentUser: nil,
      koala: self.current.koala |> Koala.lens.loggedInUser .~ nil
    )
  }

  // The most recent environment on the stack.
  public static var current: Environment! {
    return stack.last
  }

  // Push a new environment onto the stack.
  public static func pushEnvironment(_ env: Environment) {
    self.saveEnvironment(
      environment: env, ubiquitousStore: env.ubiquitousStore, userDefaults: env.userDefaults
    )
    self.stack.append(env)
  }

  // Pop an environment off the stack.
  @discardableResult
  public static func popEnvironment() -> Environment? {
    let last = self.stack.popLast()
    let next = self.current ?? Environment()
    self.saveEnvironment(
      environment: next,
      ubiquitousStore: next.ubiquitousStore,
      userDefaults: next.userDefaults
    )
    return last
  }

  // Replace the current environment with a new environment.
  public static func replaceCurrentEnvironment(_ env: Environment) {
    self.pushEnvironment(env)
    self.stack.remove(at: self.stack.count - 2)
  }

  // Pushes a new environment onto the stack that changes only a subset of the current global dependencies.
  public static func pushEnvironment(
    optimizelyClient: KSOptimizelyClientType = AppEnvironment.current.optimizelyClient,
    apiService: ServiceType = AppEnvironment.current.apiService,
    apiDelayInterval: DispatchTimeInterval = AppEnvironment.current.apiDelayInterval,
    application: UIApplicationType = UIApplication.shared,
    assetImageGeneratorType: AssetImageGeneratorType.Type = AppEnvironment.current.assetImageGeneratorType,
    cache: KSCache = AppEnvironment.current.cache,
    calendar: Calendar = AppEnvironment.current.calendar,
    config: Config? = AppEnvironment.current.config,
    cookieStorage: HTTPCookieStorageProtocol = AppEnvironment.current.cookieStorage,
    countryCode: String = AppEnvironment.current.countryCode,
    currentUser: User? = AppEnvironment.current.currentUser,
    dateType: DateProtocol.Type = AppEnvironment.current.dateType,
    debounceInterval: DispatchTimeInterval = AppEnvironment.current.debounceInterval,
    debugData: DebugData? = AppEnvironment.current.debugData,
    device: UIDeviceType = AppEnvironment.current.device,
    isVoiceOverRunning: @escaping (() -> Bool) = AppEnvironment.current.isVoiceOverRunning,
    koala: Koala = AppEnvironment.current.koala,
    language: Language = AppEnvironment.current.language,
    launchedCountries: LaunchedCountries = AppEnvironment.current.launchedCountries,
    locale: Locale = AppEnvironment.current.locale,
    mainBundle: NSBundleType = AppEnvironment.current.mainBundle,
    pushRegistrationType: PushRegistrationType.Type = AppEnvironment.current.pushRegistrationType,
    reachability: SignalProducer<Reachability, Never> = AppEnvironment.current.reachability,
    scheduler: DateScheduler = AppEnvironment.current.scheduler,
    ubiquitousStore: KeyValueStoreType = AppEnvironment.current.ubiquitousStore,
    userDefaults: KeyValueStoreType = AppEnvironment.current.userDefaults
  ) {
    self.pushEnvironment(
      Environment(
        optimizelyClient: optimizelyClient,
        apiService: apiService,
        apiDelayInterval: apiDelayInterval,
        application: application,
        assetImageGeneratorType: assetImageGeneratorType,
        cache: cache,
        calendar: calendar,
        config: config,
        cookieStorage: cookieStorage,
        countryCode: countryCode,
        currentUser: currentUser,
        dateType: dateType,
        debounceInterval: debounceInterval,
        debugData: debugData,
        device: device,
        isVoiceOverRunning: isVoiceOverRunning,
        koala: koala,
        language: language,
        launchedCountries: launchedCountries,
        locale: locale,
        mainBundle: mainBundle,
        pushRegistrationType: pushRegistrationType,
        reachability: reachability,
        scheduler: scheduler,
        ubiquitousStore: ubiquitousStore,
        userDefaults: userDefaults
      )
    )
  }

  // Replaces the current environment onto the stack with an environment that changes only a subset
  // of current global dependencies.
  public static func replaceCurrentEnvironment(
    optimizelyClient: KSOptimizelyClientType = AppEnvironment.current.optimizelyClient,
    apiService: ServiceType = AppEnvironment.current.apiService,
    apiDelayInterval: DispatchTimeInterval = AppEnvironment.current.apiDelayInterval,
    application: UIApplicationType = UIApplication.shared,
    assetImageGeneratorType: AssetImageGeneratorType.Type = AppEnvironment.current.assetImageGeneratorType,
    cache: KSCache = AppEnvironment.current.cache,
    calendar: Calendar = AppEnvironment.current.calendar,
    config: Config? = AppEnvironment.current.config,
    cookieStorage: HTTPCookieStorageProtocol = AppEnvironment.current.cookieStorage,
    countryCode: String = AppEnvironment.current.countryCode,
    currentUser: User? = AppEnvironment.current.currentUser,
    dateType: DateProtocol.Type = AppEnvironment.current.dateType,
    debounceInterval: DispatchTimeInterval = AppEnvironment.current.debounceInterval,
    debugData: DebugData? = AppEnvironment.current.debugData,
    device: UIDeviceType = AppEnvironment.current.device,
    isVoiceOverRunning: @escaping (() -> Bool) = AppEnvironment.current.isVoiceOverRunning,
    koala: Koala = AppEnvironment.current.koala,
    language: Language = AppEnvironment.current.language,
    launchedCountries: LaunchedCountries = AppEnvironment.current.launchedCountries,
    locale: Locale = AppEnvironment.current.locale,
    mainBundle: NSBundleType = AppEnvironment.current.mainBundle,
    pushRegistrationType: PushRegistrationType.Type = AppEnvironment.current.pushRegistrationType,
    reachability: SignalProducer<Reachability, Never> = AppEnvironment.current.reachability,
    scheduler: DateScheduler = AppEnvironment.current.scheduler,
    ubiquitousStore: KeyValueStoreType = AppEnvironment.current.ubiquitousStore,
    userDefaults: KeyValueStoreType = AppEnvironment.current.userDefaults
  ) {
    self.replaceCurrentEnvironment(
      Environment(
        optimizelyClient: optimizelyClient,
        apiService: apiService,
        apiDelayInterval: apiDelayInterval,
        application: application,
        assetImageGeneratorType: assetImageGeneratorType,
        cache: cache,
        calendar: calendar,
        config: config,
        cookieStorage: cookieStorage,
        countryCode: countryCode,
        currentUser: currentUser,
        dateType: dateType,
        debounceInterval: debounceInterval,
        debugData: debugData,
        device: device,
        isVoiceOverRunning: isVoiceOverRunning,
        koala: koala,
        language: language,
        launchedCountries: launchedCountries,
        locale: locale,
        mainBundle: mainBundle,
        pushRegistrationType: pushRegistrationType,
        reachability: reachability,
        scheduler: scheduler,
        ubiquitousStore: ubiquitousStore,
        userDefaults: userDefaults
      )
    )
  }

  // Returns the last saved environment from user defaults.
  public static func fromStorage(
    ubiquitousStore _: KeyValueStoreType,
    userDefaults: KeyValueStoreType
  ) -> Environment {
    let data = userDefaults.dictionary(forKey: self.environmentStorageKey) ?? [:]

    var service = self.current.apiService
    var currentUser: User?
    let config: Config? = data["config"].flatMap(decode)

    if let oauthToken = data["apiService.oauthToken.token"] as? String {
      // If there is an oauth token stored in the defaults, then we can authenticate our api service
      service = service.login(OauthToken(token: oauthToken))
      removeLegacyOauthToken(fromUserDefaults: userDefaults)
    } else if let oauthToken = legacyOauthToken(forUserDefaults: userDefaults) {
      // Otherwise if there is a token in the legacy user defaults entry we can use that
      service = service.login(OauthToken(token: oauthToken))
      removeLegacyOauthToken(fromUserDefaults: userDefaults)
    }

    // Try restoring the client id for the api service
    if let clientId = data["apiService.serverConfig.apiClientAuth.clientId"] as? String {
      service = Service(
        serverConfig: ServerConfig(
          apiBaseUrl: service.serverConfig.apiBaseUrl,
          webBaseUrl: service.serverConfig.webBaseUrl,
          apiClientAuth: ClientAuth(clientId: clientId),
          basicHTTPAuth: service.serverConfig.basicHTTPAuth,
          graphQLEndpointUrl: service.serverConfig.graphQLEndpointUrl
        ),
        oauthToken: service.oauthToken,
        language: self.current.language.rawValue,
        currency: self.current.locale.currencyCode ?? "USD"
      )
    }

    // Try restoring the base urls for the api service
    if let apiBaseUrlString = data["apiService.serverConfig.apiBaseUrl"] as? String,
      let apiBaseUrl = URL(string: apiBaseUrlString),
      let webBaseUrlString = data["apiService.serverConfig.webBaseUrl"] as? String,
      let webBaseUrl = URL(string: webBaseUrlString) {
      service = Service(
        serverConfig: ServerConfig(
          apiBaseUrl: apiBaseUrl,
          webBaseUrl: webBaseUrl,
          apiClientAuth: service.serverConfig.apiClientAuth,
          basicHTTPAuth: service.serverConfig.basicHTTPAuth,
          graphQLEndpointUrl: service.serverConfig.graphQLEndpointUrl
        ),
        oauthToken: service.oauthToken,
        language: self.current.language.rawValue,
        currency: self.current.locale.currencyCode ?? "USD"
      )
    }

    // Try restoring the basic auth data for the api service
    if let username = data["apiService.serverConfig.basicHTTPAuth.username"] as? String,
      let password = data["apiService.serverConfig.basicHTTPAuth.password"] as? String {
      service = Service(
        serverConfig: ServerConfig(
          apiBaseUrl: service.serverConfig.apiBaseUrl,
          webBaseUrl: service.serverConfig.webBaseUrl,
          apiClientAuth: service.serverConfig.apiClientAuth,
          basicHTTPAuth: BasicHTTPAuth(username: username, password: password),
          graphQLEndpointUrl: service.serverConfig.graphQLEndpointUrl
        ),
        oauthToken: service.oauthToken,
        language: self.current.language.rawValue,
        currency: self.current.locale.currencyCode ?? "USD"
      )
    }

    // Try restoring the environment
    if let environment = data["apiService.serverConfig.environment"] as? String,
      let environmentType = EnvironmentType(rawValue: environment) {
      let serverConfig = ServerConfig.config(for: environmentType)

      service = Service(
        serverConfig: serverConfig,
        oauthToken: service.oauthToken,
        language: self.current.language.rawValue,
        currency: self.current.locale.currencyCode ?? "USD"
      )
    }

    // Try restore the current user
    if service.oauthToken != nil {
      currentUser = data["currentUser"].flatMap(decode)
    }

    return Environment(
      apiService: service,
      config: config,
      currentUser: currentUser,
      koala: self.current.koala |> Koala.lens.loggedInUser .~ currentUser
    )
  }

  // Saves some key data for the current environment
  internal static func saveEnvironment(
    environment env: Environment = AppEnvironment.current,
    ubiquitousStore _: KeyValueStoreType,
    userDefaults: KeyValueStoreType
  ) {
    var data: [String: Any] = [:]

    data["apiService.oauthToken.token"] = env.apiService.oauthToken?.token
    data["apiService.serverConfig.apiBaseUrl"] = env.apiService.serverConfig.apiBaseUrl.absoluteString
    // swiftlint:disable line_length
    data["apiService.serverConfig.apiClientAuth.clientId"] = env.apiService.serverConfig.apiClientAuth.clientId
    data["apiService.serverConfig.basicHTTPAuth.username"] = env.apiService.serverConfig.basicHTTPAuth?.username
    data["apiService.serverConfig.basicHTTPAuth.password"] = env.apiService.serverConfig.basicHTTPAuth?.password
    // swiftlint:enable line_length
    data["apiService.serverConfig.webBaseUrl"] = env.apiService.serverConfig.webBaseUrl.absoluteString
    data["apiService.serverConfig.environment"] = env.apiService.serverConfig.environment.rawValue
    data["apiService.language"] = env.apiService.language
    data["apiService.currency"] = env.apiService.currency
    data["config"] = env.config?.encode()
    data["currentUser"] = env.currentUser?.encode()

    userDefaults.set(data, forKey: self.environmentStorageKey)
  }
}

private func legacyOauthToken(forUserDefaults userDefaults: KeyValueStoreType) -> String? {
  return userDefaults.object(forKey: "com.kickstarter.access_token") as? String
}

private func removeLegacyOauthToken(fromUserDefaults userDefaults: KeyValueStoreType) {
  userDefaults.removeObject(forKey: "com.kickstarter.access_token")
}
