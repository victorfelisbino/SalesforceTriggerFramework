/**
 * @description       : 
 * @author            : Victor Felisbino
 * @group             : 
 * @last modified on  : 10-26-2020
 * @last modified by  : Victor Felisbino
 * Modifications Log 
 * Ver   Date         Author             Modification
 * 1.0   10-26-2020   Victor Felisbino   Initial Version
**/
// Object:          Log class
// Business Unit:   All
// Created:         07/02/2019
// Description:
//      Common Logging Class for Console Logs + Logging to Custom Object
//
// :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
// Change History
// Date             Developer           Work Item       Description
// ---------------------------------------------------------------------------------------------------
// 07/02/2019       John Ellison        44318           Created
// :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
public class Log {
    private static final Pattern STACKTRACE_PATTERN = Pattern.compile('(?i)^(?:class\\.)?([^.]+)\\.?([^\\.\\:]+)?[\\.\\:]?([^\\.\\:]*): line (\\d+), column (\\d+)$');
    private static final Integer Error_Message_MAX_SIZE = Log__c.Exception_Message__c.getDescribe().length;

	// DEBUG
    public static void debug(String message, String source) {
        debug(message, new List<Object>(), source);
    }

    public static void debug(String message, Object param1, String source) {
        debug(message, new List<Object>{ param1 }, source);
    }

    public static void debug(String message, Object param1, Object param2, String source) {
        debug(message, new List<Object>{ param1, param2 }, source);
    }

    public static void debug(String message, Object param1, Object param2, Object param3, String source) {
        debug(message, new List<Object>{ param1, param2, param3 }, source);
    }

    public static void debug(String message, List<Object> params, String source) {
        log('Debug', message, params, null, source);
    }

	// INFO
    public static void info(String message, String source) {
        info(message, new List<Object>(), source);
    }

    public static void info(String message, Object param1, String source) {
        info(message, new List<Object>{ param1 }, source);
    }

    public static void info(String message, Object param1, Object param2, String source) {
        info(message, new List<Object>{ param1, param2 }, source);
    }

    public static void info(String message, Object param1, Object param2, Object param3, String source) {
        info(message, new List<Object>{ param1, param2, param3 }, source);
    }

    public static void info(String message, List<Object> params, String source) {
        log('Info', message, params, null, source);
    }

    // WARN
    public static void warn(String message, String source) {
        warn(message, new List<Object>(), source);
    }

    public static void warn(String message, Object param1, String source) {
        warn(message, new List<Object>{ param1 }, source);
    }

    public static void warn(String message, Object param1, Object param2, String source) {
        warn(message, new List<Object>{ param1, param2 }, source);
    }

    public static void warn(String message, Object param1, Object param2, Object param3, String source) {
        warn(message, new List<Object>{ param1, param2, param3 }, source);
    }

    public static void warn(String message, List<Object> params, String source) {
        log('Warning', message, params, null, source);
    }

    // ERROR
    public static void error(Exception error, String source) {
        error(null, new List<Object>(), error, source);
    }

    public static void error(String message, Exception error, String source) {
        error(message, new List<Object>(), error, source);
    }

    public static void error(String message, Object param1, Exception error, String source) {
        error(message, new List<Object>{ param1 }, error, source);
    }

    public static void error(String message, Object param1, Object param2, Exception error, String source) {
        error(message, new List<Object>{ param1, param2 }, error, source);
    }

    public static void error(String message, Object param1, Object param2, Object param3, Exception error, String source) {
        error(message, new List<Object>{ param1, param2, param3 }, error, source);
    }

    public static void error(String message, List<Object> params, Exception error, String source) {
        log('Error', message, params, error, source);
    }

    // COMMON LOG LOGIC
    //todo: remove required source field for all Log.debug() statements, then fix the callers
    private static void log(String level, String message, List<Object> params,  Exception error, String source) {
        if (!isLoggingEnabled()) {
            return;
        }

        if(params == null) {
            params = new List<Object>();
        }

        List<String> values = new List<String>();
        for(Object param : params) {
            values.add(String.valueOf(param));
        }

        if(message != null) {
            message = message + values;
        }

        //create logging context
        Context ctx = createContext();
        ctx.level = level;
        ctx.message = message;
        ctx.error = error;
        ctx.source = source;

        //log the entry
        generateLog(ctx);
    }

    private static Context createContext() {
        String stackTraceString = new DmlException().getStackTraceString();
        stackTraceString = stackTraceString.substringAfter('\n');
        stackTraceString = stackTraceString.substringAfter('\n');
        stackTraceString = stackTraceString.substringAfter('\n');
        stackTraceString = stackTraceString.substringAfter('\n');
        stackTraceString = stackTraceString.substringBefore('\n');

        Matcher m = Log.STACKTRACE_PATTERN.matcher(stackTraceString);

        Context ctx = new Context();
        if(m.find()) {
            if(String.isBlank(m.group(3))) {
                ctx.className = m.group(1);
                ctx.methodName = prettifyMethodName(m.group(2));
            } else {
                ctx.className = m.group(1) + '.' + m.group(2);
                ctx.methodName = prettifyMethodName(m.group(3));
            }
            ctx.line = Integer.valueOf(m.group(4));
            ctx.column = Integer.valueOf(m.group(5));
        }

        return ctx;
    }

    public static void generateLog(Context ctx) {
        String prefixPattern = getPrefixPattern();
        String prefix = getPrefix(ctx, prefixPattern);

        createConsoleLog(ctx.level, prefix, ctx.message, ctx.error, ctx.source);
        if (ctx.level != 'Debug') {
            createLogEntry(ctx.level, ctx.message, ctx.className, ctx.error, ctx.source);
        }
    }

    private static String getPrefix(Context ctx, String prefixPattern) {
        //DefaultAppender == '%t.%m Line %l Column %c - '
        String prefix = prefixPattern;
        prefix = prefix.replaceAll('%t', ctx.className);
        prefix = prefix.replaceAll('%m', ctx.methodName);
        prefix = prefix.replaceAll('%l', String.valueOf(ctx.line));
        prefix = prefix.replaceAll('%c', String.valueOf(ctx.column));

        return prefix;
    }

    private static String getPrefixPattern() {
        return '%t.%m Line %l Column %c - ';
    }

    private static void createConsoleLog(String level, String prefix, String message, Exception e, String source) {
        if(level == 'Error') {
            if(prefix != null) {
                System.debug(prefix);
                if(e != null){
                    System.debug(e.getMessage());
                    System.debug(e.getStackTraceString());
                }
            }else if(e != null) {
                System.debug(e);
                System.debug(e.getStackTraceString());
            }
        }
        else if(level == 'Warning') {
            System.debug('Warning: ' + prefix);
        }
        else if(level == 'Info') {
            System.debug('Info: ' + prefix + message);
        }
        else if(level == 'Debug') {
            System.debug(prefix + message);
        }
    }

    public static void createLogEntry(String level, String message, String className, Exception e, String source){
        Log__c log = new Log__c();
        try{
        	log.RecordTypeId = Global_Util.getRecordType('Log__c', level).Id;
        }catch(Exception ex){
            log.RecordTypeId = Global_Util.getRecordType('Log__c', 'Error').Id;
        }
        log.Source__c = source;
        log.Component_Name__c = className;
        log.Message__c = getLogMessage(message, e);
        if(e != null){
            log.Exception_Message__c = e?.getMessage()?.abbreviate(Error_Message_MAX_SIZE);
            log.Stack_Trace__c = e.getStackTraceString();
        }

        if(System.isFuture() || System.isBatch()) insertLog(JSON.serialize(log));
        else insertLogAsync(JSON.serialize(log));

    }

    @future
    private static void insertLogAsync(String stringyLog){
        Log__c log = (Log__c) JSON.deserializeStrict(stringyLog, Log__c.class);
        insert log;
    }

    private static void insertLog(String stringyLog){
        Log__c log = (Log__c) JSON.deserializeStrict(stringyLog, Log__c.class);
        insert log;
    }

    //todo - function build on reverse logic. Should return true is logging is enabled. Rewrite (07/15/20)
    private static Boolean isLoggingEnabled(){
        if(System.isFuture()){
            String env = EnvVariable.getValue('LoggingFutureEnabled');
            if(env == null || env.toLowerCase() != 'true') return false;
        }else{
            String env = EnvVariable.getValue('LoggingEnabled');
            if(env == null || env.toLowerCase() != 'true') return false;
        }
        return true;
    }


    private static String getLogMessage(String message, Exception e){
        if(String.isNotBlank(message)) return message;
        if(e != null){
            return e.getMessage();
        }
        return 'Unknown';
    }

    private static String prettifyMethodName(String name) {
		return (name == null) ? '(unknown method)' :
		       name.replace('<init>', '(constructor) ').replace('__sfdc_', '(getter/setter) ');
	}

	// LOGGING CONTEXT
    public class Context {
        public String logger;
        public String className;
        public String methodName;
        public Integer line;
        public Integer column;
        public String level;
        public String message;
        public Exception error;
        public String source;
    }
}