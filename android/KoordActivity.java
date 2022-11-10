// For custom url handling on Android
// taken from: https://github.com/ucam-department-of-psychiatry/camcops/pull/185/files#diff-ef3481aa73554877e3b5e2b7e0e79dcfc63815b5db2783116d3f12df5ec1e726

public class KoordActivity extends QtActivity
{
    // Defined in urlhandler.cpp
    public static native void handleAndroidUrl(String url);

    @Override
    public void onCreate(Bundle savedInstanceState) {
        // Called when no instance of the app is running. Pass URL parameters
        // as arguments to the app's main()
        Intent intent = getIntent();

        if (intent != null && intent.getAction() == Intent.ACTION_VIEW) {
            Uri uri = intent.getData();
            if (uri != null) {
                Log.i(TAG, intent.getDataString());

                Map<String, String> parameters = getQueryParameters(uri);
         
                StringBuilder sb = new StringBuilder();

                String separator = "";
                for (Map.Entry<String, String> entry : parameters.entrySet()) {
                    String name = entry.getKey();
                    String value = entry.getValue();
                    if (value != null) {
                        sb.append(separator)
                            .append("--").append(name)
                            .append("=").append(value);

                        separator = "\t";
                    }
                }

                APPLICATION_PARAMETERS = sb.toString();
            }
        }

        super.onCreate(savedInstanceState);
    }

    @Override
    public void onNewIntent(Intent intent) {
        /* Called when the app is already running. Send the URL parameters
         * as signals to the app.
         */
        super.onNewIntent(intent);

        sendUrlToApp(intent);
    }

    private void sendUrlToApp(Intent intent) {
        String url = intent.getDataString();

        if (url != null) {
            handleAndroidUrl(url);
        }
    }

    private Map<String, String> getQueryParameters(Uri uri) {
        List<String> names = Arrays.asList("parameter1",
                                           "parameter2",
                                           "parameter3");

        Map<String, String> parameters = new HashMap<String, String>();

        for (String name : names) {
            String value = uri.getQueryParameter(name);
            if (value != null) {
                parameters.put(name, value);
            }
        }

        return parameters;
    }