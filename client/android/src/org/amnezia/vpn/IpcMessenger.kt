package org.amnezia.vpn

import android.os.DeadObjectException
import android.os.Message
import android.os.Messenger
import android.os.RemoteException
import org.amnezia.vpn.util.Log

private const val TAG = "IpcMessenger"

class IpcMessenger(
    messengerName: String? = null,
    private val onDeadObjectException: () -> Unit = {},
    private val onRemoteException: () -> Unit = {}
) {
    private var messenger: Messenger? = null
    // CottonVPN: send() раньше молча терял команду, если messenger ещё null (окно между
    // onStop→onStart, пока сервис не привязался заново) — заявленная кнопка «выключить»
    // не долетала до сервиса вообще, без единой ошибки. Теперь такие команды копятся и
    // досылаются в set(), когда привязка появится.
    private val pending = mutableListOf<Message>()
    val name = messengerName ?: "Unknown"

    constructor(
        messenger: Messenger,
        messengerName: String? = null,
        onDeadObjectException: () -> Unit = {},
        onRemoteException: () -> Unit = {}
    ) : this(messengerName, onDeadObjectException, onRemoteException) {
        this.messenger = messenger
    }

    // ⚠️ set() НЕ досылает очередь сам. Раньше досылал — и накопленный DISCONNECT улетал
    // в сервис ДО того, как активность успевала зарегистрироваться клиентом (REGISTER_CLIENT
    // отправляется следующей строкой). Сервис честно выключал VPN, но уведомлять о смене
    // статуса было ещё некого: подтверждение не приходило, кнопка оставалась зелёной при
    // выключенном VPN. Досылку теперь запускает вызывающий — ПОСЛЕ регистрации.
    fun set(messenger: Messenger) {
        this.messenger = messenger
    }

    /** Досылает команды, накопленные пока привязки не было. Звать после REGISTER_CLIENT. */
    fun flushPending() {
        val m = messenger ?: return
        if (pending.isEmpty()) return
        val queued = pending.toList()
        pending.clear()
        queued.forEach { m.sendMsg(it) }
    }

    fun reset() {
        messenger = null
    }

    fun send(msg: () -> Message) = sendOrQueue(msg())

    fun send(msg: Message, replyTo: Messenger) = sendOrQueue(msg.apply { this.replyTo = replyTo })

    fun <T> send(msg: T)
        where T : Enum<T>, T : IpcMessage = sendOrQueue(msg.packToMessage())

    fun <T> send(msg: T, replyTo: Messenger)
        where T : Enum<T>, T : IpcMessage = sendOrQueue(msg.packToMessage().apply { this.replyTo = replyTo })

    private fun sendOrQueue(msg: Message) {
        val m = messenger
        if (m == null) {
            Log.d(TAG, "$name messenger not bound yet, queuing message")
            pending += msg
        } else {
            m.sendMsg(msg)
        }
    }

    private fun Messenger.sendMsg(msg: Message) {
        try {
            send(msg)
        } catch (e: DeadObjectException) {
            Log.w(TAG, "$name messenger is dead")
            messenger = null
            onDeadObjectException()
        } catch (e: RemoteException) {
            Log.w(TAG, "Sending a message to the $name messenger failed: ${e.message}")
            onRemoteException()
        }
    }
}

fun Map<Messenger, IpcMessenger>.send(msg: () -> Message) = this.values.forEach { it.send(msg) }

fun <T> Map<Messenger, IpcMessenger>.send(msg: T)
    where T : Enum<T>, T : IpcMessage = this.values.forEach { it.send(msg) }
