import android.app {
    ActivityManager
}
import android.graphics {
    BitmapFactory
}
import android.media {
    MediaMetadata
}
import android {
    AndroidR=R
}
import com.example.android.uamp {
    R,
    MusicService
}
import android.content {
    ComponentName,
    Context
}
import android.media.browse {
    MediaBrowser
}
import android.media.session {
    PlaybackState,
    MediaSession,
    MediaController
}
import com.example.android.uamp.utils {
     ResourceHelper,
    LogHelper
}
import android.os {
    Bundle,
    Build,
    RemoteException
}
import android.net {
    ConnectivityManager
}

shared abstract class BaseActivity()
        extends ActionBarCastActivity()
        satisfies MediaBrowserProvider {

    value tag = LogHelper.makeLogTag(`BaseActivity`);

    shared actual late MediaBrowser mediaBrowser;
    late variable PlaybackControlsFragment controlsFragment;

    shared Boolean online {
        assert (is ConnectivityManager connMgr = getSystemService(Context.connectivityService));
        return if (exists networkInfo = connMgr.activeNetworkInfo) then networkInfo.connected else false;
    }

    void showPlaybackControls() {
        LogHelper.d(tag, "showPlaybackControls");
        if (online) {
            fragmentManager.beginTransaction()
                .setCustomAnimations(
                R.Animator.slide_in_from_bottom,
                R.Animator.slide_out_to_bottom,
                R.Animator.slide_in_from_bottom,
                R.Animator.slide_out_to_bottom)
                .show(controlsFragment)
                .commit();
        }
    }

    void hidePlaybackControls() {
        LogHelper.d(tag, "hidePlaybackControls");
        fragmentManager.beginTransaction()
            .hide(controlsFragment)
            .commit();
    }

    function shouldShowControls() {
        if (exists mediaController = this.mediaController,
            mediaController.metadata exists,
            mediaController.playbackState exists) {
            return mediaController.playbackState.state != PlaybackState.stateError;
        }
        else {
            return false;
        }
    }

    class MediaControllerCallback()
            extends MediaController.Callback() {
        shared actual void onPlaybackStateChanged(PlaybackState state) {
            if (shouldShowControls()) {
                showPlaybackControls();
            } else {
                LogHelper.d(tag, "mediaControllerCallback.onPlaybackStateChanged: hiding controls because state is ", state.state);
                hidePlaybackControls();
            }
        }
        shared actual void onMetadataChanged(MediaMetadata metadata) {
            if (shouldShowControls()) {
                showPlaybackControls();
            } else {
                LogHelper.d(tag, "mediaControllerCallback.onMetadataChanged: hiding controls because metadata is null");
                hidePlaybackControls();
            }
        }
    }

    shared default void onMediaControllerConnected() {}

    void connectToSession(MediaSession.Token token) {
        mediaController = MediaController(this, token);
        mediaController.registerCallback(MediaControllerCallback());
        if (shouldShowControls()) {
            showPlaybackControls();
        } else {
            LogHelper.d(tag, "connectionCallback.onConnected: hiding controls because metadata is null");
            hidePlaybackControls();
        }
        controlsFragment.onConnected();
        onMediaControllerConnected();
    }

    shared actual default void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LogHelper.d(tag, "Activity onCreate");
        if (Build.VERSION.sdkInt >= 21) {
            value taskDesc
                    = ActivityManager.TaskDescription(title.string,
                BitmapFactory.decodeResource(resources, R.Drawable.ic_launcher_white),
                ResourceHelper.getThemeColor(this, R.Attr.colorPrimary, AndroidR.Color.darker_gray));
            setTaskDescription(taskDesc);
        }
        mediaBrowser = MediaBrowser(this,
            ComponentName(this, `MusicService`),
            object extends MediaBrowser.ConnectionCallback() {
                shared actual void onConnected() {
                    LogHelper.d(tag, "onConnected");
                    try {
                        connectToSession(mediaBrowser.sessionToken);
                    }
                    catch (RemoteException e) {
                        //LogHelper.e(tag, e, "could not connect media controller");
                        hidePlaybackControls();
                    }
                }
            },
            null);
    }

    shared actual void onStart() {
        super.onStart();
        LogHelper.d(tag, "Activity onStart");
        "Mising fragment with id 'controls'. Cannot continue."
        assert (is PlaybackControlsFragment fragment
                = fragmentManager.findFragmentById(R.Id.fragment_playback_controls));
        controlsFragment = fragment;
        hidePlaybackControls();
        mediaBrowser.connect();
    }

    shared actual void onStop() {
        super.onStop();
        LogHelper.d(tag, "Activity onStop");
        mediaController?.unregisterCallback(MediaControllerCallback());
        mediaBrowser.disconnect();
    }

}