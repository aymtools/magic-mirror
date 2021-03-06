import '../core.dart';
import '../tools.dart';
import 'class_mirror.dart';
import 'exception.dart';
import 'initializer.dart';
import 'type_adapter.dart';

///类信息注册器
abstract class IMirrorRegister {
  List<MirrorClass> classInfos();

// List<String> loadInitializer();
//
// List<String> loadTypeAdapter();
}

///所有的工具入口 利用预生成的策略生成可能用到的类的类似反射的使用模式
class MagicMirror implements IMirrorRegister {
  MagicMirror._();

  static final MagicMirror _instance = MagicMirror._();

  factory MagicMirror() => _instance;

  static MagicMirror get instance => _instance;

  IMirrorRegister? _register;

  _MirrorRegister? _registers;

  final Map<Type, Map<Type, TypeConvert>> _typeAdapter = {};

  final Map<String, MirrorClass> _mirrorClassesK = {};

  final Map<Type, MirrorClass> _mirrorClassesT = {};

  final List<MirrorClass> _mirrorClasses = [];

  ///绑定注册器，只可以调用一次
  void bindRegister(IMirrorRegister register) {
    if (_register == null) {
      _register = _registers == null
          ? register
          : (_MirrorRegister(register)..bindSecRegister(_registers!));
      _register!.classInfos().forEach((element) {
        _mirrorClasses.add(element);
        _mirrorClassesK[element.key] = element;
        _mirrorClassesT[element.type.typeValue] = element;
      });
      LoadTypeAdapter().onInit(this);
      loadInitializer()
          .map((e) => newSingleInstance(e))
          .whereType<Initializer>()
          .forEach((element) => element.onInit(instance));
      // _register
      //     .loadInitializer()
      //     .map((e) => parseUriInfoByUriStr(e))
      //     .map((e) => newInstance(e.key, e.namedConstructorInUri, e.uriParams))
      //     .whereType<MirrorInitializer>()
      //     .forEach((element) => element.onInit(this));
    } else {
      throw Exception('MagicMirror is initialized');
    }
  }

  ///绑定注册器，只可以调用一次
  static void register(IMirrorRegister register) {
    instance.bindRegister(register);
  }

  ///绑定注册器列表，可以的多次调用 当调用register后不可再次调用
  static void registers(IMirrorRegister register) {
    if (instance._register == null) {
      instance._registers = instance._registers == null
          ? _MirrorRegister(register)
          : (_MirrorRegister(register)..bindSecRegister(instance._registers!));
    } else {
      throw Exception(
          'registerInvokers is close ! must register before registerInvoker');
    }
  }

  ///注册类型转换器，根据已有的类信息生成
  void registerTypeAdapter2(String typeAdapterClassUri) {
    registerTypeAdapter(newSingleInstance(typeAdapterClassUri));
  }

  ///注册类型转换器
  void registerTypeAdapter<From, To>(TypeConvert<From, To> convert) {
    var adapter =
        _typeAdapter.putIfAbsent(convert.from, () => <Type, TypeConvert>{});
    adapter[convert.to] = convert;

    if (convert is TypeConvertAdapter<From, To>) {
      var adapter2 =
          _typeAdapter.putIfAbsent(convert.to, () => <Type, TypeConvert>{});
      adapter2[convert.from] = _TypeReverse<From, To>(convert);
    }
  }

  ///分析从uri中可提取的类信息 包括key 构造函数 uri参数
  static ClassUriInfo parseClassUriInfoByUriStr(String uri) =>
      parseClassUriInfo(Uri.parse(uri));

  ///分析从uri中可提取的类信息 包括key 构造函数 uri参数
  static ClassUriInfo parseClassUriInfo(Uri u) => instance.parseUriInfo(u);

  ///分析从uri中可提取的类的key信息
  static String getClassKey(Uri u) {
    return instance.parseUriInfo(u).key;
  }

  ///分析从uri中可提取的类的命名构造函数
  static String getNamedConstructorInUri(Uri u) {
    return instance.parseUriInfo(u).namedConstructorInUri;
  }

  static final Map<String, dynamic> _singleInstances = {};

  ///根据uri 和传入的参数信息实例化对象
  static T newInstanceS<T>(String uri, {dynamic param}) {
    return instance.newInstanceByUri(uri, param: param);
  }

  ///根据uri 和传入的参数信息实例化对象
  static T newInstanceSI<T>(ClassUriInfo uriInfo, {dynamic param}) {
    return instance.newInstanceByClassUriInfo(uriInfo, param: param);
  }

  ///调用该对象的指定方法
  static dynamic invokeMethodS<T>(T bean, String methodName,
          {Map<String, dynamic> params = const {}}) =>
      instance.invokeMethod(bean, methodName, params: params);

  ///获取对象中的属性值
  static dynamic getFieldValueS<T>(T bean, String fieldName) =>
      instance.getFieldValue(bean, fieldName);

  ///设定对象中的属性值
  static void setFieldValueS<T>(T bean, String fieldName, dynamic value) =>
      instance.setFieldValue(bean, fieldName, value);

  ///将所有的可获取的属性全部获取 为map
  static Map<String, dynamic> getAllFieldValue<T>(T bean) =>
      instance.getFieldValues(bean);

  ///将map中的值自动赋值到对应是属性上
  static void setFieldValueByMap<T>(T bean, Map<String, dynamic> values) =>
      instance.setFieldValues(bean, values);

  ///尝试将form转换为目标类型
  static To? convertTypeS<To>(dynamic from) => instance.convertType(from);

  ///尝试将form转换为目标类型  转换失败将返回null
  To? convertType<To>(dynamic from) {
    if (from == null) return null;
    if (dynamic == To) return from;
    if (from is To) return from;
    Type fromType = from.runtimeType;
    if (fromType == To) {
      return from as To;
    } else if (hasTypeAdapter(fromType, To)) {
      try {
        var converter = _typeAdapter[fromType]?[To];
        return converter?.convert(from);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  //判断是否包含 from到to的类型转换器
  static bool hasTypeAdapterS(Type from, Type to) =>
      instance.hasTypeAdapter(from, to);

  //判断是否包含 from到to的类型转换器
  static bool hasTypeAdapterS1<From>(Type to) =>
      instance.hasTypeAdapter(From, to);

  //判断是否包含 from到to的类型转换器
  static bool hasTypeAdapterS2<To>(Type from) =>
      instance.hasTypeAdapter(from, To);

  //判断是否包含 from对象转换为to的类型转换器
  static bool hasTypeAdapterS2Value<To>(dynamic fromValue) => fromValue == null
      ? true
      : (fromValue is To) || hasTypeAdapterS2<To>(fromValue.runtimeType);

  //判断是否包含 from对象转换为to的类型转换器
  static bool hasTypeAdapterSValue(dynamic fromValue, Type to) =>
      fromValue == null
          ? true
          : (fromValue.runtimeType == to) ||
              hasTypeAdapterS(fromValue.runtimeType, to);

  //判断是否包含 from到to的类型转换器
  static bool hasTypeAdapterS3<From, To>() => instance.hasTypeAdapter(From, To);

  ///获取泛型类型的具体类型
  static Type genType<T>() => T;

  //判断是否包含 from对象转换为to的类型转换器
  bool hasTypeAdapter(Type from, Type to) =>
      from == to ||
      Object == to ||
      dynamic == to ||
      (_typeAdapter.containsKey(from) &&
          _typeAdapter[from] != null &&
          _typeAdapter[from]!.containsKey(to));

  ///判断form是否可以转换为目标类型
  bool canCovertTo<To>(dynamic fromValue) => fromValue == null
      ? true
      : (fromValue is To) || hasTypeAdapterS2<To>(fromValue.runtimeType);

  ///分析从uri中可提取的类信息 包括key 构造函数 uri参数
  ClassUriInfo parseUriInfoByUriStr(String uri) {
    return parseUriInfo(Uri.parse(uri));
  }

  ///分析从uri中可提取的类信息 包括key 构造函数 uri参数
  ClassUriInfo parseUriInfo(Uri u) {
    var pathSegments = u.pathSegments;

    var queryParameters = u.queryParameters;
//    Map<String, List<String>> queryParametersAll = u.queryParametersAll;
    var namedConstructorInUri = '';
    if (pathSegments.isNotEmpty) {
      var lastPathS = pathSegments[pathSegments.length - 1];
      var lastPathSF = lastPathS.lastIndexOf('.');
      if (lastPathSF > -1) {
        namedConstructorInUri = lastPathS.substring(lastPathSF + 1);
        var lastPathRe = lastPathS.substring(0, lastPathSF);
        pathSegments = List.from(pathSegments, growable: false);
        pathSegments[pathSegments.length - 1] = lastPathRe;
        u = u.replace(pathSegments: pathSegments);
      } else {
        namedConstructorInUri = '';
      }
    } else {
      //如果是如 Invoker://test.named 也可以尝试进行解析  但如 Invoker://xxxx.test.named 为了安全起见 不解析 最好遵照uri的标准用法
      if (u.hasAuthority &&
          !u.authority.contains(':') &&
          u.authority.indexOf('.') == u.authority.lastIndexOf('.')) {
        var authority = u.authority;
        var ni = authority.lastIndexOf('.');
        namedConstructorInUri = ni > -1 ? authority.substring(ni + 1) : '';
        var newAuthority = ni > -1 ? authority.substring(0, ni) : authority;
        u = u.replace(host: newAuthority);
      }
    }
    u = u.replace(queryParameters: {});

    var uri = u.toString();

    if (uri.endsWith('?')) {
      uri = uri.substring(0, uri.length - 1);
    }

    return ClassUriInfo(uri, namedConstructorInUri, queryParameters);
  }

  ///获取所有的自动扫描到的类型转换器
  List<String> loadTypeAdapter() => findClassesUris<TypeAdapter, TypeConvert>();

  ///获取所有的自动扫描到的初始化触发器
  List<String> loadInitializer() =>
      findClassesUris<OnInitializer, Initializer>();

  ///根据注解类型 CLass的类型来获取对应的类信息
  List<MirrorClass<ExtendsType, AnnotationType>>
      findClasses<AnnotationType extends MReflectionEnable, ExtendsType>() =>
          _mirrorClasses
              // .where((element) =>
              //     element.type is TypeToken<ExtendsType> &&
              //     element.annotationType is TypeToken<AnnotationType>)
              .whereType<MirrorClass<ExtendsType, AnnotationType>>()
              .toList();

  ///根据注解类型 CLass的类型来获取对应的类信息
  List<String> findClassesUris<AnnotationType extends MReflectionEnable,
          ExtendsType>() =>
      findClasses<AnnotationType, ExtendsType>().map((e) => e.key).toList();

  ///根据注解类型 CLass的类型来获取对应的类信息
  List<MirrorClass<dynamic, AnnotationType>> findClassesByAnnotation<
          AnnotationType extends MReflectionEnable>() =>
      _mirrorClasses.whereType<MirrorClass<dynamic, AnnotationType>>().toList();

  ///根据注解类型来获取对应的类信息
  List<String>
      findClassesUrisByAnnotation<AnnotationType extends MReflectionEnable>() =>
          findClassesByAnnotation<AnnotationType>().map((e) => e.key).toList();

  ///根据CLass的类型来获取对应的类信息
  List<MirrorClass<ExtendsType, MReflectionEnable>>
      findClassesByExtends<ExtendsType>() => _mirrorClasses
          .whereType<MirrorClass<ExtendsType, MReflectionEnable>>()
          .toList();

  ///根据CLass的类型来获取对应的类信息
  List<String> findClassesUrisByExtends<ExtendsType>() =>
      findClassesByExtends<ExtendsType>().map((e) => e.key).toList();

  ///获取所有的注册的类信息列表
  @override
  List<MirrorClass> classInfos() => _register?.classInfos() ?? [];

  ///根据key信息自动加载对应的类信息
  MirrorClass<T, MReflectionEnable> loadClass<T>(String classKey) {
    if (_mirrorClassesK.containsKey(classKey)) {
      return _mirrorClassesK[classKey] as MirrorClass<T, MReflectionEnable>;
    }
    throw ClassNotFoundException(classKey);
  }

  ///根据具体类型 加载对应的类信息 ，可能会找不到 未注册
  MirrorClass<T, MReflectionEnable> mirrorClass<T>() {
    Type type = genType<T>();
    if (_mirrorClassesT.containsKey(type)) {
      return _mirrorClassesT[type] as MirrorClass<T, MReflectionEnable>;
    }
    throw ClassNotConfigException(type);
  }

  ///判断根据key和命名构造函数 是否可以构造该类的实例
  bool canNewInstance(String classKey, String namedConstructor) {
    try {
      MirrorClass clazz = loadClass(classKey);
      clazz.getConstructor(namedConstructor);
      return true;
    } on MagicMirrorException {
      return false;
    }
  }

  ///根据uri 和传入的参数信息实例化对象
  T newInstanceByUri<T>(String uri, {dynamic param}) {
    var info = parseUriInfoByUriStr(uri);
    return newInstanceByClassUriInfo(info, param: param);
  }

  ///根据uri 和传入的参数信息实例化对象
  T newInstanceByClassUriInfo<T>(ClassUriInfo uriInfo, {dynamic param}) {
    return newInstance(
        uriInfo.key, uriInfo.namedConstructorInUri, uriInfo.uriParams,
        param: param);
  }

  ///根据key 命名构造函数 uri参数 和传入的参数信息实例化对象
  T newInstance<T>(
      String classKey, String? namedConstructor, Map<String, String> uriParams,
      {dynamic param}) {
    var params = <String, dynamic>{};
    MirrorClass<T, MReflectionEnable> clazz = loadClass<T>(classKey);
    MirrorConstructor<T, MAnnotation> constructor =
        clazz.getConstructor(namedConstructor);
    if (constructor.params.isNotEmpty) {
      params = genParams(param, uriParams, constructor.params.first.key);
    }
    return constructor.newInstance(params);
  }

  ///根据uri实例化单例模式的类实例
  T newSingleInstance<T>(String uri) {
    var info = parseUriInfoByUriStr(uri);
    if (_singleInstances.containsKey(info.key)) {
      return _singleInstances[info.key] as T;
    }
    T result =
        newInstance(info.key, info.namedConstructorInUri, info.uriParams);
    if (result != null) _singleInstances[info.key] = result;
    return result;
  }

  ///执行类中的指定方法
  R? invokeMethod<T, R>(T bean, String methodName,
      {Map<String, dynamic> params = const {}}) {
    MirrorClass<T, dynamic> clazz = mirrorClass<T>();
    MirrorFunction<T, MAnnotation, dynamic> function =
        clazz.getFunction(methodName);
    return function.invoke(bean, params);
  }

  ///执行为类对象的属性赋值
  void setFieldValue<T, V>(T bean, String fieldName, V value) {
    MirrorClass<T, dynamic> clazz = mirrorClass<T>();
    MirrorField<T, dynamic, dynamic> field = clazz.getField(fieldName);
    if (field.hasSetter) {
      field.set(bean, value);
    } else {
      throw NoSuchFunctionException(bean.runtimeType, 'set $fieldName');
    }
  }

  ///获取为类对象的属性的具体值
  V? getFieldValue<T, V>(T bean, String fieldName) {
    MirrorClass<T, dynamic> clazz = mirrorClass<T>();
    MirrorField<T, dynamic, dynamic> field = clazz.getField(fieldName);
    if (field.hasGetter) {
      return field.get(bean);
    } else {
      throw NoSuchFunctionException(bean.runtimeType, 'get $fieldName');
    }
  }

  ///将map中的值自动赋值到对应是属性上
  void setFieldValues<T>(T bean, Map<String, dynamic> values) {
    MirrorClass<T, dynamic> clazz = mirrorClass<T>();
    clazz.fields.where((element) => element.hasSetter).forEach((element) {
      if (values.containsKey(element.key)) {
        try {
          setFieldValue(bean, element.key, values[element.key]);
        } on IllegalArgumentException {
          ///忽略赋值异常 继续后续的赋值
        }
      }
    });
  }

  ///将所有的可获取的属性全部获取 为map
  Map<String, dynamic> getFieldValues<T>(T bean) {
    var result = <String, dynamic>{};
    MirrorClass<T, dynamic> clazz = mirrorClass<T>();
    clazz.fields.where((element) => element.hasGetter).forEach((element) {
      result[element.key] = element.get(bean);
    });
    return result;
  }
}

///从uri中解析到的类信息
class ClassUriInfo {
  ///类的ky
  final String key;

  ///命名构造函数的名字
  final String namedConstructorInUri;

  ///uir中包含的参数信息
  final Map<String, String> uriParams;

  ClassUriInfo(this.key, this.namedConstructorInUri, this.uriParams);
}

///用来支持反转类型转换器
class _TypeReverse<From, To> extends TypeConvert<To, From> {
  _TypeReverse(this._reverse);

  Type get from => _reverse.to;

  Type get to => _reverse.from;

  final TypeConvertAdapter<From, To> _reverse;

  @override
  From? convert(To value) => _reverse.reverse(value);
}

///具体的代理执行器 自动实现多个嵌套等操作
class _MirrorRegister implements IMirrorRegister {
  final IMirrorRegister _primaryInvoker;

  IMirrorRegister? _secInvoker;

  _MirrorRegister(this._primaryInvoker);

  ///嵌套第二个执行器
  void bindSecRegister(IMirrorRegister secInvoker) {
    var sec = _secInvoker;
    if (sec == null) {
      _secInvoker = secInvoker;
    } else if (sec is _MirrorRegister) {
      sec.bindSecRegister(secInvoker);
    } else {
      _secInvoker = _MirrorRegister(sec);
      (_secInvoker as _MirrorRegister).bindSecRegister(secInvoker);
    }
  }

  ///获取所有的嵌套的执行器中注册的类信息
  @override
  List<MirrorClass> classInfos() {
    var result = List.from(_primaryInvoker.classInfos())
        .whereType<MirrorClass>()
        .toList(growable: true);

    var sec = _secInvoker;
    if (sec != null) result.addAll(sec.classInfos());
    return result;
  }
}
