using System;
using System.Collections.Generic;
using UnityEngine;

namespace FantasyWord.GameCore
{
    internal enum ETerrainDestinationResolutionFailure
    {
        None = 0,
        StartNodeUnavailable = 1,
        NoCandidate = 2,
        Unreachable = 3,
        Ambiguous = 4
    }

    internal readonly struct TerrainDestinationCandidate
    {
        public TerrainDestinationCandidate(
            in TerrainNodeKey nodeKey,
            Vector2 worldPosition,
            bool wasSnapped)
        {
            NodeKey = nodeKey;
            WorldPosition = worldPosition;
            WasSnapped = wasSnapped;
        }

        public TerrainNodeKey NodeKey { get; }
        public Vector2 WorldPosition { get; }
        public bool WasSnapped { get; }
    }

    internal sealed class TerrainDestinationResolver
    {
        private readonly List<TerrainDestinationCandidate> m_candidates = new();
        private readonly List<TerrainNodeKey> m_pathScratch = new();

        public bool TryResolveStart(
            TerrainNavigationMap map,
            Vector2 startWorld,
            int currentLayerId,
            out TerrainDestinationCandidate start)
        {
            if (map == null)
            {
                throw new ArgumentNullException(nameof(map));
            }

            return map.TryResolveNavigationCandidateOnLayer(
                startWorld,
                currentLayerId,
                out start);
        }

        public bool TryResolveDestination(
            TerrainNavigationMap map,
            in TerrainNodeKey startNode,
            Vector2 destinationWorld,
            int currentLayerId,
            out TerrainDestinationCandidate destination,
            out ETerrainDestinationResolutionFailure failure)
        {
            if (map == null)
            {
                throw new ArgumentNullException(nameof(map));
            }

            map.CollectNavigationCandidates(destinationWorld, m_candidates);
            if (m_candidates.Count == 0)
            {
                destination = default;
                failure = ETerrainDestinationResolutionFailure.NoCandidate;
                return false;
            }

            int reachableCount = 0;
            TerrainDestinationCandidate uniqueReachable = default;
            bool hasReachableCurrentLayer = false;
            TerrainDestinationCandidate reachableCurrentLayer = default;
            for (int i = 0; i < m_candidates.Count; i++)
            {
                TerrainDestinationCandidate candidate = m_candidates[i];
                if (!map.TryBuildNodePath(startNode, candidate.NodeKey, m_pathScratch))
                {
                    continue;
                }

                reachableCount++;
                uniqueReachable = candidate;
                if (candidate.NodeKey.LayerId == currentLayerId)
                {
                    hasReachableCurrentLayer = true;
                    reachableCurrentLayer = candidate;
                }
            }

            if (hasReachableCurrentLayer)
            {
                destination = reachableCurrentLayer;
                failure = ETerrainDestinationResolutionFailure.None;
                return true;
            }

            if (reachableCount == 1)
            {
                destination = uniqueReachable;
                failure = ETerrainDestinationResolutionFailure.None;
                return true;
            }

            destination = default;
            failure = reachableCount == 0
                ? ETerrainDestinationResolutionFailure.Unreachable
                : ETerrainDestinationResolutionFailure.Ambiguous;
            return false;
        }
    }
}
