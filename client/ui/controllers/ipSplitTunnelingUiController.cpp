#include "ipSplitTunnelingUiController.h"

#include <QDebug>
#include <QFile>
#include <QMap>
#include <QSet>

#include "systemController.h"
#include "core/utils/errorCodes.h"
#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"

IpSplitTunnelingUiController::IpSplitTunnelingUiController(IpSplitTunnelingController* ipSplitTunnelingController,
                                                          IpSplitTunnelingModel* ipSplitTunnelingModel, QObject *parent)
    : QObject(parent),
      m_ipSplitTunnelingController(ipSplitTunnelingController),
      m_ipSplitTunnelingModel(ipSplitTunnelingModel)
{
    m_ipSplitTunnelingModel->updateModel(m_ipSplitTunnelingController->getCurrentSites());

    // самовосстановление пресета «РУ напрямую»: если он включён, а сохранённый список
    // отличается от вшитого (например, ru_ip.txt обновили в новой версии) — перезаписываем.
    if (isRussiaPresetEnabled()) {
        const QMap<QString, QString> preset = russiaPresetSites();
        // сверяем СОДЕРЖИМОЕ, а не размер: в обновлении список может смениться при
        // том же числе сетей (бюджет маршрутов фиксирован) — по размеру это не видно
        QSet<QString> storedSites;
        for (const auto &site : m_ipSplitTunnelingController->getCurrentSites()) {
            storedSites.insert(site.first);
        }
        QSet<QString> presetSites;
        for (auto it = preset.keyBegin(); it != preset.keyEnd(); ++it) {
            presetSites.insert(*it);
        }
        if (!preset.isEmpty() && storedSites != presetSites) {
            m_ipSplitTunnelingController->addSites(preset, true); // replaceExisting
            qInfo() << "RussiaPreset: stored site list refreshed to" << preset.size() << "entries";
        }
    }
}

void IpSplitTunnelingUiController::addSite(QString hostname)
{
    if (m_ipSplitTunnelingController->addSite(hostname)) {
        emit finished(tr("New site added: %1").arg(hostname));
    }
}

void IpSplitTunnelingUiController::removeSite(int index)
{
    auto modelIndex = m_ipSplitTunnelingModel->index(index);
    auto hostname = m_ipSplitTunnelingModel->data(modelIndex, IpSplitTunnelingModel::Roles::UrlRole).toString();
    if (m_ipSplitTunnelingController->removeSite(hostname)) {
        emit finished(tr("Site removed: %1").arg(hostname));
    }
}

void IpSplitTunnelingUiController::removeSites()
{
    m_ipSplitTunnelingController->removeSites();
    emit finished(tr("Site list cleared!"));
}

void IpSplitTunnelingUiController::importSites(const QString &fileName, bool replaceExisting)
{
    QByteArray jsonData;
    if (!SystemController::readFile(fileName, jsonData)) {
        emit errorOccurred(tr("Can't open file: %1").arg(fileName));
        return;
    }

    QString errorMessage;
    if (m_ipSplitTunnelingController->importSitesFromJson(jsonData, replaceExisting, errorMessage)) {
        emit finished(tr("Import completed"));
    } else {
        emit errorOccurred(errorMessage);
    }
}

void IpSplitTunnelingUiController::exportSites(const QString &fileName)
{
    QByteArray jsonData = m_ipSplitTunnelingController->exportSitesToJson();
    if (!SystemController::saveFile(fileName, jsonData)) {
        qInfo() << "IpSplitTunnelingUiController::exportSites: save or share was cancelled or failed";
        return;
    }
    emit finished(tr("Export completed"));
}

void IpSplitTunnelingUiController::toggleSplitTunneling(bool enabled)
{
    m_ipSplitTunnelingController->toggleSplitTunneling(enabled);
    emit isSplitTunnelingEnabledChanged();
}

void IpSplitTunnelingUiController::setRouteMode(int routeMode)
{
    m_ipSplitTunnelingController->setRouteMode(static_cast<amnezia::RouteMode>(routeMode));
    emit routeModeChanged();
}

int IpSplitTunnelingUiController::getRouteMode() const
{
    return static_cast<int>(m_ipSplitTunnelingController->getRouteMode());
}

bool IpSplitTunnelingUiController::isSplitTunnelingEnabled() const
{
    return m_ipSplitTunnelingController->isSplitTunnelingEnabled();
}

void IpSplitTunnelingUiController::updateModel()
{
    m_ipSplitTunnelingModel->updateModel(m_ipSplitTunnelingController->getCurrentSites());
}

QMap<QString, QString> IpSplitTunnelingUiController::russiaPresetSites() const
{
    // встроенный список РУ-IP (CIDR с маской; vpnConnection принимает subnet-формат как есть).
    // Список компактный (~700 сетей): маршруты уходят в Android одной binder-транзакцией
    // с лимитом ~1МБ, а на Android <13 exclude-сети ещё и разворачиваются вычитанием
    // из 0.0.0.0/0 — тысячи записей ломали establish() (VPN не поднимался).
    QFile f(QStringLiteral(":/client_scripts/ru_ip.txt"));
    QMap<QString, QString> sites;
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        while (!f.atEnd()) {
            const QString line = QString::fromUtf8(f.readLine()).trimmed();
            if (!line.isEmpty() && line.contains(QLatin1Char('/'))) {
                sites.insert(line, line);
            }
        }
        f.close();
    }
    return sites;
}

void IpSplitTunnelingUiController::enableRussiaPreset()
{
    // «всё через VPN, кроме списка» — список российских IP пойдёт напрямую
    m_ipSplitTunnelingController->setRouteMode(amnezia::RouteMode::VpnAllExceptSites);

    const QMap<QString, QString> sites = russiaPresetSites();
    if (!sites.isEmpty()) {
        m_ipSplitTunnelingController->addSites(sites, true); // replaceExisting
    }
    m_ipSplitTunnelingController->toggleSplitTunneling(true);

    // updateModel() намеренно не вызываем: список на нашем экране не показывается,
    // построение модели впустую подвесило бы UI при переключении тумблера.
    emit routeModeChanged();
    emit isSplitTunnelingEnabledChanged();
}

void IpSplitTunnelingUiController::disableRussiaPreset()
{
    m_ipSplitTunnelingController->toggleSplitTunneling(false);
    emit isSplitTunnelingEnabledChanged();
}

bool IpSplitTunnelingUiController::isRussiaPresetEnabled() const
{
    return m_ipSplitTunnelingController->isSplitTunnelingEnabled()
            && m_ipSplitTunnelingController->getRouteMode() == amnezia::RouteMode::VpnAllExceptSites;
}
