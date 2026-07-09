using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Tilemaps;

/*
 * This class requires the 2d-extras repo from unity
 * available here for versions lower than 2020.1: https://github.com/Unity-Technologies/2d-extras
 * and in the package manager (as tilemap-extras) for 2020.1 and above.
 */

namespace Minifantasy
{
    [CreateAssetMenu]
    public class WhitelistOverrideRuleTile : RuleTile
    {
        public List<TileBase> m_WhiteListTiles = new List<TileBase>();

        public override bool RuleMatch(int neighbor, TileBase other)
        {
            switch (neighbor)
            {
                case TilingRule.Neighbor.This:
                    foreach (TileBase tb in m_WhiteListTiles)
                    {
                        if (other == tb)
                            return true;
                    }
                    break;
                case TilingRule.Neighbor.NotThis:
                    foreach (TileBase tb in m_WhiteListTiles)
                    {
                        if (other == tb)
                            return false;
                    }
                    break;
            }

            return base.RuleMatch(neighbor, other);
        }

    }
}